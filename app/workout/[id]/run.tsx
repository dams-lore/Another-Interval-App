import React, { useEffect, useRef, useState } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, Alert, useWindowDimensions,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter, useLocalSearchParams, Stack } from 'expo-router';
import { useKeepAwake } from 'expo-keep-awake';
import * as Haptics from 'expo-haptics';
import * as Location from 'expo-location';
import { createAudioPlayer, setAudioModeAsync } from 'expo-audio';
import type { AudioPlayer } from 'expo-audio';
import { File, Paths } from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Svg, { Circle, Text as SvgText, TSpan } from 'react-native-svg';
import { useWorkoutStore } from '../../../store/workoutStore';
import { useSessionStore } from '../../../store/sessionStore';
import { useRecordsStore } from '../../../store/recordsStore';
import { useHeartRateStore } from '../../../store/heartRateStore';
import { Step } from '../../../types/workout';
import { BlockResult, HrSample } from '../../../types/session';
import { isMovingActivity } from '../../../utils/isMovingActivity';

// ── SVG constants ──────────────────────────────────────────────────────────
const C_RADIUS      = 118;
const C_SIZE        = 260;
const C_CENTER      = C_SIZE / 2;   // 130
const CIRCUMFERENCE = 2 * Math.PI * C_RADIUS; // ≈ 741.4

const DISPLAY_MODE_KEY = 'intrvl-display-mode';
type DisplayMode = 'compact' | 'gym';

// ── Helpers ────────────────────────────────────────────────────────────────
function getStepDuration(step: Step): number | null {
  if (step.type !== 'time') return null;
  return step.unit === 'min' ? step.value * 60 : step.value;
}

function fmt(totalSeconds: number): string {
  const m = Math.floor(Math.abs(totalSeconds) / 60);
  const s = Math.abs(totalSeconds) % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function fmtShort(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return m > 0 ? `${m}'${String(s).padStart(2, '0')}"` : `${s}"`;
}

/** Convertit une vitesse km/h en allure min:sec/km */
function speedToPace(kmh: number): string {
  if (!kmh || kmh <= 0) return '--';
  const secPerKm = 3600 / kmh;
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}'${String(s).padStart(2, '0')}/km`;
}

type RunStatus = 'running' | 'paused' | 'done';
type CompletedBlock = { name: string; blockNum: number; duration_s: number };

// ── Beep generation — 880 Hz sine wave, WAV in base64, no external file ───
function makeSineWAV(freqHz: number, durationMs: number, amplitude = 0.55): Uint8Array {
  const SR = 44100;
  const n  = Math.floor(SR * durationMs / 1000);
  const buf = new ArrayBuffer(44 + n * 2);
  const v   = new DataView(buf);
  const ws  = (off: number, s: string) => { for (let i = 0; i < s.length; i++) v.setUint8(off + i, s.charCodeAt(i)); };
  ws(0,  'RIFF'); v.setUint32(4,  36 + n * 2, true); ws(8, 'WAVE');
  ws(12, 'fmt '); v.setUint32(16, 16,  true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, SR, true); v.setUint32(28, SR * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  ws(36, 'data'); v.setUint32(40, n * 2, true);
  const dur  = durationMs / 1000;
  const fade = 0.008;
  for (let i = 0; i < n; i++) {
    const t   = i / SR;
    const env = t < fade ? t / fade : t > dur - fade ? (dur - t) / fade : 1;
    const pcm = Math.max(-32768, Math.min(32767, Math.round(Math.sin(2 * Math.PI * freqHz * t) * amplitude * env * 32767)));
    v.setInt16(44 + i * 2, pcm, true);
  }
  return new Uint8Array(buf);
}

export default function RunScreen() {
  useKeepAwake();

  const router                = useRouter();
  const { id }                = useLocalSearchParams<{ id: string }>();
  const { getById }           = useWorkoutStore();
  const { setPendingSession } = useSessionStore();
  const { getPaceForLabel }   = useRecordsStore();
  const { bpm }               = useHeartRateStore();
  const bpmRef                = useRef<number | null>(null);
  useEffect(() => { bpmRef.current = bpm; }, [bpm]);
  const hrSamplesRef          = useRef<HrSample[]>([]);
  const workout               = getById(id ?? '');

  const totalBlocks = workout?.steps.length ?? 0;
  const totalRounds = workout?.format === 'intervals' ? (workout?.rounds ?? 1) : 1;

  // ── Display mode ───────────────────────────────────────────────────────────
  const [displayMode, setDisplayMode] = useState<DisplayMode>('compact');

  useEffect(() => {
    AsyncStorage.getItem(DISPLAY_MODE_KEY).then((v) => {
      if (v === 'gym' || v === 'compact') setDisplayMode(v);
    });
  }, []);

  async function toggleMode() {
    const next: DisplayMode = displayMode === 'compact' ? 'gym' : 'compact';
    setDisplayMode(next);
    await AsyncStorage.setItem(DISPLAY_MODE_KEY, next);
  }

  const gym = displayMode === 'gym';

  // ── Countdown 3-2-1-GO ─────────────────────────────────────────────────────
  const [countdown, setCountdown] = useState<number | null>(3); // null = pas de countdown
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // ── Audio beep ─────────────────────────────────────────────────────────────
  const beepRef      = useRef<AudioPlayer | null>(null);
  const beepFinalRef = useRef<AudioPlayer | null>(null);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        await setAudioModeAsync({
          playsInSilentMode: true,
          interruptionMode: 'mixWithOthers',
        });
        const beepFile      = new File(Paths.cache, 'intrvl_beep.wav');
        const beepFinalFile = new File(Paths.cache, 'intrvl_beep_final.wav');
        beepFile.write(makeSineWAV(880, 180));
        beepFinalFile.write(makeSineWAV(880, 540));
        if (!mounted) return;
        beepRef.current      = createAudioPlayer({ uri: beepFile.uri });
        beepFinalRef.current = createAudioPlayer({ uri: beepFinalFile.uri });
        console.log('[AUDIO] beep + beep-final ready ✓');
      } catch (e) {
        console.log('[AUDIO] init error:', e);
      }
    })();
    return () => {
      mounted = false;
      beepRef.current?.remove();
      beepFinalRef.current?.remove();
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function playBeep() {
    try {
      if (beepRef.current) {
        beepRef.current.seekTo(0);
        beepRef.current.play();
      }
    } catch (e) {
      console.log('[AUDIO] play error:', e);
    }
  }

  function playBeepFinal() {
    try {
      if (beepFinalRef.current) {
        beepFinalRef.current.seekTo(0);
        beepFinalRef.current.play();
      }
    } catch (e) {
      console.log('[AUDIO] play final error:', e);
    }
  }

  // ── Mutable timer state ────────────────────────────────────────────────
  const run = useRef({
    blockIndex:           0,
    roundIndex:           0,
    elapsed:              0,
    blockElapsed:         0,
    blockTimeLeft:        workout ? getStepDuration(workout.steps[0]) : null,
    initialBlockDuration: workout ? getStepDuration(workout.steps[0]) : null,
    blockStartedAt:       new Date(),
    blockResults:         [] as BlockResult[],
    warnedAt10:           false,
  });

  const sessionStartedAt = useRef(new Date());
  const intervalRef      = useRef<ReturnType<typeof setInterval> | null>(null);

  const startTimerRef    = useRef<() => void>(() => {});
  const advanceBlockRef  = useRef<() => void>(() => {});
  const finishSessionRef = useRef<() => void>(() => {});

  const [status, setStatus] = useState<RunStatus>('running');
  const [completedBlocks, setCompletedBlocks] = useState<CompletedBlock[]>([]);

  // ── GPS Speed ──────────────────────────────────────────────────────────────
  const [gpsSpeed, setGpsSpeed]   = useState<number | null>(null); // km/h
  const [gpsPermGranted, setGpsPermGranted] = useState(false);

  // Demande de permission une seule fois au montage
  useEffect(() => {
    let mounted = true;
    Location.requestForegroundPermissionsAsync().then(({ status }) => {
      if (mounted && status === 'granted') setGpsPermGranted(true);
    });
    return () => { mounted = false; };
  }, []);

  // Démarre/arrête le suivi GPS en fonction du mouvement courant
  useEffect(() => {
    if (!gpsPermGranted) return;
    const movement = workout?.steps[run.current.blockIndex]?.movement ?? '';
    if (!isMovingActivity(movement)) {
      setGpsSpeed(null);
      return;
    }
    let active = true;
    let sub: Location.LocationSubscription | null = null;
    (async () => {
      sub = await Location.watchPositionAsync(
        { accuracy: Location.Accuracy.BestForNavigation, timeInterval: 1000, distanceInterval: 1 },
        (loc) => {
          if (!active) return;
          const spd = loc.coords.speed ?? 0;
          setGpsSpeed(spd > 0 ? Math.round(spd * 3.6 * 10) / 10 : 0);
        }
      );
    })();
    return () => {
      active = false;
      sub?.remove();
      setGpsSpeed(null);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [gpsPermGranted, completedBlocks]);
  const [, setTick] = useState(0);
  const rerender = () => setTick((t) => t + 1);

  // ── Warning ────────────────────────────────────────────────────────────────
  async function triggerWarning() {
    console.log('[WARNING] triggerWarning fired — elapsed:', run.current.elapsed, 'blockElapsed:', run.current.blockElapsed);
    playBeep();
    // Fort : notification Error d'abord (le plus intense), puis 8x Heavy rapides
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    for (let i = 0; i < 8; i++) {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      if (i < 7) await new Promise(r => setTimeout(r, 40));
    }
  }

  // ── Finish session ──────────────────────────────────────────────────────
  function finishSession() {
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = null;
    setStatus('done');
    // Bip de fin de session
    playBeepFinal();
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const r = run.current;
    setPendingSession({
      workoutId:        id ?? '',
      workoutName:      workout?.name ?? '',
      format:           workout?.format ?? '',
      rounds_completed: r.roundIndex + 1,
      started_at:       sessionStartedAt.current.toISOString(),
      ended_at:         new Date().toISOString(),
      duration_s:       r.elapsed,
      block_results:    r.blockResults,
      hrSamples:        hrSamplesRef.current.length > 0 ? [...hrSamplesRef.current] : undefined,
    });
    router.replace({ pathname: '/workout/[id]/summary', params: { id: id ?? '' } });
  }

  // ── Advance to next block ───────────────────────────────────────────────
  function advanceBlock() {
    if (!workout) return;
    const r = run.current;

    const completedStep = workout.steps[r.blockIndex];
    r.blockResults = [
      ...r.blockResults,
      {
        stepId:     completedStep.id,
        roundIndex: r.roundIndex,
        started_at: r.blockStartedAt.toISOString(),
        ended_at:   new Date().toISOString(),
        duration_s: r.blockElapsed,
      },
    ];
    setCompletedBlocks((prev) => [
      ...prev,
      { name: completedStep.movement, blockNum: r.blockIndex + 1, duration_s: r.blockElapsed },
    ]);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    const nextBlock = r.blockIndex + 1;
    if (nextBlock >= totalBlocks) {
      const nextRound          = r.roundIndex + 1;
      const intervalsExhausted = workout.format === 'intervals' && nextRound >= totalRounds;
      const forTimeDone        = workout.format === 'for_time';
      if (forTimeDone || intervalsExhausted) {
        finishSessionRef.current();
        return;
      }
      r.roundIndex = nextRound;
      r.blockIndex = 0;
    } else {
      r.blockIndex = nextBlock;
    }

    r.blockElapsed         = 0;
    r.blockStartedAt       = new Date();
    r.blockTimeLeft        = getStepDuration(workout.steps[r.blockIndex]);
    r.initialBlockDuration = getStepDuration(workout.steps[r.blockIndex]);
    r.warnedAt10           = false;

    rerender();
    startTimerRef.current();
  }

  // ── Timer interval ──────────────────────────────────────────────────────
  function startTimer() {
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => {
      const r = run.current;
      r.elapsed      += 1;
      r.blockElapsed += 1;

      if (r.elapsed % 5 === 0 && bpmRef.current !== null) {
        hrSamplesRef.current.push({ t: r.elapsed, bpm: bpmRef.current });
      }

      if (workout?.cap_time != null) {
        const capRemaining = workout.cap_time - r.elapsed;
        if (capRemaining === 10 && !r.warnedAt10) {
          r.warnedAt10 = true;
          triggerWarning();
        }
        if (workout.format === 'amrap' && r.elapsed >= workout.cap_time) {
          console.log('[AMRAP] cap_time reached — elapsed:', r.elapsed, '→ finishSession');
          clearInterval(intervalRef.current!);
          intervalRef.current = null;
          finishSessionRef.current();
          return;
        }
      }

      if (r.blockTimeLeft !== null) {
        r.blockTimeLeft -= 1;
        const remaining = r.initialBlockDuration! - r.blockElapsed;
        if (remaining === 10 && !r.warnedAt10) {
          r.warnedAt10 = true;
          triggerWarning();
        }
        if (r.blockTimeLeft <= 0) {
          console.log('[INTERVALS] block countdown done — blockIndex:', r.blockIndex, '→ advanceBlock');
          clearInterval(intervalRef.current!);
          intervalRef.current = null;
          // Bip de fin de bloc
          playBeepFinal();
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          advanceBlockRef.current();
          return;
        }
      }

      rerender();
    }, 1000);
  }

  startTimerRef.current    = startTimer;
  advanceBlockRef.current  = advanceBlock;
  finishSessionRef.current = finishSession;

  // ── Countdown then start ────────────────────────────────────────────────
  function startCountdownThenTimer() {
    if (countdownRef.current) clearInterval(countdownRef.current);
    setCountdown(3);
    let n = 3;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    countdownRef.current = setInterval(() => {
      n -= 1;
      if (n > 0) {
        setCountdown(n);
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      } else if (n === 0) {
        setCountdown(0); // "GO"
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        playBeep();
      } else {
        // n < 0 → on lance
        clearInterval(countdownRef.current!);
        countdownRef.current = null;
        setCountdown(null);
        startTimerRef.current();
      }
    }, 1000);
  }

  useEffect(() => {
    startCountdownThenTimer();
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
      if (countdownRef.current) clearInterval(countdownRef.current);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Pause / resume / stop ───────────────────────────────────────────────
  function pause() {
    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = null;
    setStatus('paused');
  }

  function resume() {
    setStatus('running');
    startTimerRef.current();
  }

  function handleStop() {
    pause();
    Alert.alert('Stop workout', 'Que veux-tu faire ?', [
      { text: 'Continuer', style: 'cancel', onPress: resume },
      { text: 'Abandonner', style: 'destructive', onPress: () => router.back() },
      {
        text: 'Garder la progression',
        onPress: () => {
          const r = run.current;
          setPendingSession({
            workoutId:        id ?? '',
            workoutName:      workout?.name ?? '',
            format:           workout?.format ?? '',
            rounds_completed: r.roundIndex + 1,
            started_at:       sessionStartedAt.current.toISOString(),
            ended_at:         new Date().toISOString(),
            duration_s:       r.elapsed,
            block_results:    r.blockResults,
            hrSamples:        hrSamplesRef.current.length > 0 ? [...hrSamplesRef.current] : undefined,
          });
          router.replace({ pathname: '/workout/[id]/summary', params: { id: id ?? '' } });
        },
      },
    ]);
  }

  // ── Guard ───────────────────────────────────────────────────────────────
  if (!workout) {
    return (
      <SafeAreaView style={s.safe}>
        <Stack.Screen options={{ headerShown: false }} />
        <Text style={s.errorText}>Workout not found</Text>
      </SafeAreaView>
    );
  }

  // ── Derived display values ──────────────────────────────────────────────
  const r           = run.current;
  const currentStep = workout.steps[r.blockIndex];
  const isTimed     = currentStep?.type === 'time';

  const movLen        = currentStep?.movement?.length ?? 0;
  const movFontSize    = movLen <= 12 ? 44 : movLen <= 20 ? 34 : 26;
  const gymMovFontSize = movLen <= 12 ? 32 : movLen <= 20 ? 26 : 20;
  const showGps       = isMovingActivity(currentStep?.movement ?? '');

  const { width, height } = useWindowDimensions();
  // pleine largeur : "00:00" en Bebas Neue ≈ 2.75× la taille ; capé sur hauteur/7 pour SE
  const timerFontSize = Math.min(Math.floor((width - 32) / 2.75), Math.floor(height / 7));
  const hrFontSize    = Math.round(timerFontSize * 0.38);
  const speedFontSize = Math.round(timerFontSize * 0.28);

  let mainTimer: number;
  let timerLabel: string;
  if (workout.format === 'intervals') {
    mainTimer  = r.initialBlockDuration !== null
      ? Math.max(0, r.initialBlockDuration - r.blockElapsed)
      : r.blockElapsed;
    timerLabel = 'BLOC';
  } else if (workout.format === 'amrap' && workout.cap_time != null) {
    mainTimer  = Math.max(0, workout.cap_time - r.elapsed);
    timerLabel = 'RESTANT';
  } else {
    mainTimer  = r.elapsed;
    timerLabel = 'TEMPS';
  }

  // Gym mode central timer — toujours le temps du bloc courant, jamais le total session
  // For Time  : blockElapsed (temps passé sur le bloc)
  // AMRAP     : countdown cap restant
  // Intervals : countdown si timed, blockElapsed sinon
  const gymMainTimer =
    workout.format === 'amrap' && workout.cap_time != null
      ? Math.max(0, workout.cap_time - r.elapsed)
      : workout.format === 'intervals' && r.initialBlockDuration !== null
        ? Math.max(0, r.initialBlockDuration - r.blockElapsed)
        : r.blockElapsed;

  // Circle (compact / intervals only)
  const showCircle = !gym && workout.format === 'intervals';
  let circleRatio: number;
  if (r.initialBlockDuration !== null) {
    circleRatio = Math.max(0, r.initialBlockDuration - r.blockElapsed) / r.initialBlockDuration;
  } else {
    circleRatio = 1 - ((r.blockElapsed % 60) / 60);
  }
  const circleOffset = CIRCUMFERENCE * (1 - circleRatio);

  const isWarning =
    workout.format === 'intervals' &&
    r.initialBlockDuration !== null &&
    mainTimer > 0 &&
    mainTimer <= 10;

  const arcColor   = isWarning ? RED : GREEN;
  const timerColor = isWarning ? RED : CREAM;

  const totalDone = r.roundIndex * totalBlocks + r.blockIndex;
  const totalAll  = totalRounds * totalBlocks;
  const progress  = totalAll > 0 ? totalDone / totalAll : 0;

  const lastCompleted = completedBlocks[completedBlocks.length - 1];
  const prevText = lastCompleted
    ? `${lastCompleted.name} ${lastCompleted.blockNum} : ${fmtShort(lastCompleted.duration_s)}`
    : '--';

  // ── Mode toggle pill (shared) ───────────────────────────────────────────
  const modePill = (
    <TouchableOpacity style={[s.modePill, gym && s.modePillGym]} onPress={toggleMode} activeOpacity={0.75}>
      <Text style={[s.modePillSegment, !gym && s.modePillSegmentActive, gym && s.modePillSegmentGymInactive]}>
        compact
      </Text>
      <Text style={[s.modePillDivider, gym && s.modePillDividerGym]}>|</Text>
      <Text style={[s.modePillSegment, gym && s.modePillSegmentActive, !gym && s.modePillSegmentGymInactive, gym && s.modePillSegmentGymActive]}>
        gym
      </Text>
    </TouchableOpacity>
  );

  // ── GYM MODE A — "Stack" ──────────────────────────────────────────────
  if (gym) {
    const hasAction  = workout.format === 'intervals' || !isTimed;
    const isAmrap    = workout.format === 'amrap';
    // AMRAP : un seul chrono (pas d'elapsed séparé)
    const showElapsedAbove = !isAmrap;

    return (
      <View style={sA.gymFullScreen}>
        <Stack.Screen options={{ headerShown: false }} />
        <StatusBar style="dark" hidden />

        {/* Floating: Stop (gauche) · Round + modePill (droite) */}
        <View style={s.gymOverlayTop} pointerEvents="box-none">
          <TouchableOpacity style={s.gymStopFloat} onPress={handleStop} activeOpacity={0.8}>
            <Text style={s.gymStopFloatText}>■  Stop</Text>
          </TouchableOpacity>
          <View style={s.gymOverlayRight} pointerEvents="auto">
            {workout.format === 'intervals' && totalRounds > 1 && (
              <View style={sA.gymRoundBadge}>
                <Text style={sA.gymRoundBadgeText}>Round {r.roundIndex + 1} / {totalRounds}</Text>
              </View>
            )}
            {modePill}
          </View>
        </View>

        {/* Timer section */}
        <View style={s.gymTimerSection}>
          {showElapsedAbove && (
            <>
              <Text style={sA.gymElapsedAbove}>{fmt(r.elapsed)}</Text>
              <View style={sA.gymSeparator} />
            </>
          )}
          <Text style={s.gymTimer} numberOfLines={1} adjustsFontSizeToFit>
            {fmt(gymMainTimer)}
          </Text>
          {/* GPS Speed — seulement pour activités de déplacement */}
          <View style={s.gpsSlotGym}>
            {showGps && gpsSpeed !== null && (
              <View style={sGps.row}>
                <Text style={sGps.speed}>{gpsSpeed} km/h</Text>
                <Text style={sGps.sep}>·</Text>
                <Text style={sGps.pace}>{speedToPace(gpsSpeed)}</Text>
              </View>
            )}
          </View>
          {/* Fréquence cardiaque */}
          <Text style={s.hrTextGym}>♥  {bpm !== null ? `${bpm} bpm` : '-- bpm'}</Text>
          {status === 'paused' && <Text style={s.gymPausedBadge}>PAUSED</Text>}
        </View>

        {/* Block info */}
        <View style={s.gymBlockSection}>
          <Text style={s.gymBlockIndexLabel}>BLOCK {r.blockIndex + 1} / {totalBlocks}</Text>
          <Text style={[s.gymMovementText, { fontSize: gymMovFontSize }]} numberOfLines={2}>
            {currentStep?.movement}
          </Text>
          <View style={s.tagRow}>
            {currentStep?.type === 'reps' && (
              <View style={s.tagGym}><Text style={s.tagTextGym}>{currentStep.value} reps</Text></View>
            )}
            {currentStep?.type === 'distance' && (
              <View style={s.tagGym}><Text style={s.tagTextGym}>{currentStep.value} {currentStep.unit}</Text></View>
            )}
            {currentStep?.type === 'time' && (
              <View style={s.tagGym}><Text style={s.tagTextGym}>{currentStep.value} {currentStep.unit}</Text></View>
            )}
            {currentStep?.weight != null && (
              <View style={s.tagGym}><Text style={s.tagTextGym}>{currentStep.weight} {currentStep.weight_unit ?? 'kg'}</Text></View>
            )}
            {currentStep?.notes != null && (
              <View style={s.tagGym}><Text style={s.tagTextGym}>{currentStep.notes}</Text></View>
            )}
          </View>
          <Text style={s.gymPrevBlock}>{prevText}</Text>
        </View>

        {/* Progress */}
        <View style={s.progressRow}>
          <View style={s.progressTrackGym}>
            <View style={[s.progressFillGym, { width: `${Math.round(progress * 100)}%` as any }]} />
          </View>
          <Text style={s.progressLabelGym}>{totalDone + 1} / {totalAll}</Text>
        </View>

        {/* Boutons */}
        <View style={sA.gymBtnRow}>
          {hasAction && (
            <TouchableOpacity
              style={[sA.gymActionBtn, status === 'paused' && sA.gymActionBtnSmall]}
              onPress={() => advanceBlockRef.current()}
              activeOpacity={0.85}
            >
              <Text style={sA.gymActionBtnText}>
                {workout.format === 'intervals' ? '⏭  Skip' : '✓  Done'}
              </Text>
            </TouchableOpacity>
          )}
          {status === 'running' ? (
            <TouchableOpacity
              style={[sA.gymPauseBtn, !hasAction && { flex: 1 }]}
              onPress={pause}
              activeOpacity={0.8}
            >
              <Text style={sA.gymPauseBtnText}>⏸</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity
              style={[sA.gymResumeBtn, !hasAction && { flex: 1 }]}
              onPress={resume}
              activeOpacity={0.85}
            >
              <Text style={sA.gymResumeBtnText}>▶  Resume</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Countdown overlay */}
        {countdown !== null && (
          <View style={sCD.overlay}>
            <Text style={sCD.countText}>
              {countdown === 0 ? 'GO' : String(countdown)}
            </Text>
          </View>
        )}
      </View>
    );
  }

  // ── COMPACT MODE (existing layout) ─────────────────────────────────────
  return (
    <SafeAreaView style={s.safe} edges={['top', 'bottom']}>
      <Stack.Screen options={{ headerShown: false }} />
      <StatusBar style="light" />

      {/* Top bar */}
      <View style={s.topBar}>
        <TouchableOpacity style={s.stopTap} onPress={handleStop} activeOpacity={0.8}>
          <Text style={s.stopText}>■  Stop</Text>
        </TouchableOpacity>

        <View style={s.topBarRight}>
          {workout.format === 'intervals' && (
            <View style={s.pill}>
              <Text style={s.pillText}>Round {r.roundIndex + 1} / {totalRounds}</Text>
            </View>
          )}
          <View style={s.pill}>
            <Text style={s.pillText}>{fmt(r.elapsed)}</Text>
          </View>
          {modePill}
        </View>
      </View>

      {/* Current block info */}
      <View style={s.blockSection}>
        <Text style={s.blockIndexLabel}>
          BLOCK {r.blockIndex + 1} / {totalBlocks}
        </Text>
        <Text style={[s.movementText, { fontSize: movFontSize }]} numberOfLines={2}>
          {currentStep?.movement}
        </Text>
        <View style={s.tagRow}>
          {currentStep?.type === 'reps' && (
            <View style={s.tag}><Text style={s.tagText}>{currentStep.value} reps</Text></View>
          )}
          {currentStep?.type === 'distance' && (
            <View style={s.tag}>
              <Text style={s.tagText}>{currentStep.value} {currentStep.unit}</Text>
            </View>
          )}
          {currentStep?.type === 'time' && (
            <View style={s.tag}>
              <Text style={s.tagText}>{currentStep.value} {currentStep.unit}</Text>
            </View>
          )}
          {currentStep?.target_pace != null && (() => {
            const pace = getPaceForLabel(currentStep.target_pace);
            return pace ? (
              <View style={s.tag}>
                <Text style={s.tagText}>🏃 {pace.pace_label}  ·  {pace.speed_label}</Text>
              </View>
            ) : (
              <View style={s.tag}><Text style={s.tagText}>@{currentStep.target_pace} pace</Text></View>
            );
          })()}
          {currentStep?.weight != null && (
            <View style={s.tag}>
              <Text style={s.tagText}>{currentStep.weight} {currentStep.weight_unit ?? 'kg'}</Text>
            </View>
          )}
          {currentStep?.notes != null && (
            <View style={s.tag}><Text style={s.tagText}>{currentStep.notes}</Text></View>
          )}
        </View>
      </View>

      {/* Chrono + cardio + vitesse */}
      <View style={s.timerSection}>

        {/* Chrono pleine largeur */}
        <Text style={[s.timerDisplay, { fontSize: timerFontSize, lineHeight: Math.round(timerFontSize * 1.05), color: timerColor }]}>
          {`${String(Math.floor(Math.abs(mainTimer) / 60)).padStart(2, '0')}:${String(Math.abs(mainTimer) % 60).padStart(2, '0')}`}
        </Text>

        {/* Fréquence cardiaque */}
        <View style={s.hrRowBig}>
          <Text style={[s.hrHeartBig, { fontSize: hrFontSize, lineHeight: Math.round(hrFontSize * 1.1) }]}>♥</Text>
          <Text style={[s.hrValueBig, { fontSize: hrFontSize, lineHeight: Math.round(hrFontSize * 1.1) }]}>
            {bpm !== null ? String(bpm) : '--'}
          </Text>
          <Text style={s.hrUnitBig}>bpm</Text>
        </View>

        {/* Vitesse GPS — slot toujours présent */}
        <View style={s.gpsSlot}>
          {showGps && gpsSpeed !== null && (
            <View style={s.gpsRowBig}>
              <Text style={[s.gpsSpeedBig, { fontSize: speedFontSize, lineHeight: Math.round(speedFontSize * 1.1), transform: [{ skewX: '-10deg' as any }] }]}>
                {gpsSpeed}
              </Text>
              <Text style={s.gpsUnitBig}>km/h</Text>
              <Text style={s.gpsSepBig}>·</Text>
              <Text style={s.gpsPaceBig}>{speedToPace(gpsSpeed)}</Text>
            </View>
          )}
        </View>

        {/* Infos bloc précédent + PAUSED */}
        <View style={s.bottomSlot}>
          {lastCompleted && <Text style={s.prevBlock}>{prevText}</Text>}
          {status === 'paused' && <Text style={s.pausedBadge}>PAUSED</Text>}
        </View>
      </View>

      {/* Progress bar */}
      <View style={s.progressRow}>
        <View style={s.progressTrack}>
          <View style={[s.progressFill, { width: `${Math.round(progress * 100)}%` as any }]} />
        </View>
        <Text style={s.progressLabel}>{totalDone + 1} / {totalAll}</Text>
      </View>

      {/* Controls */}
      <View style={s.controls}>
        {workout.format === 'intervals' ? (
          <TouchableOpacity style={s.doneBtn} onPress={() => advanceBlockRef.current()} activeOpacity={0.85}>
            <Text style={s.doneBtnText}>⏭  Skip</Text>
          </TouchableOpacity>
        ) : !isTimed ? (
          <TouchableOpacity style={s.doneBtn} onPress={() => advanceBlockRef.current()} activeOpacity={0.85}>
            <Text style={s.doneBtnText}>✓  Done</Text>
          </TouchableOpacity>
        ) : null}

        {status === 'running' ? (
          <TouchableOpacity style={s.pauseBtn} onPress={pause} activeOpacity={0.8}>
            <Text style={s.pauseBtnText}>⏸  Pause</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={s.resumeBtn} onPress={resume} activeOpacity={0.85}>
            <Text style={s.resumeBtnText}>▶  Resume</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Countdown overlay */}
      {countdown !== null && (
        <View style={sCD.overlay}>
          <Text style={[sCD.countText, { color: '#fff' }]}>
            {countdown === 0 ? 'GO' : String(countdown)}
          </Text>
        </View>
      )}
    </SafeAreaView>
  );
}

// ── Design tokens ────────────────────────────────────────────────────────────
const DARK   = '#1A1714';
const CREAM  = '#F0EFEB';
const PURPLE = '#A793AC';
const GREEN  = '#7DB87A';
const RED    = '#E05555';
const MUTED  = '#6B6560';
const GYM_BG = '#aaee66';

const s = StyleSheet.create({
  // ── Compact base ──────────────────────────────────────────────────────────
  safe:      { flex: 1, backgroundColor: DARK },
  errorText: { color: CREAM, textAlign: 'center', marginTop: 60, fontSize: 16, fontFamily: 'Inter_400Regular' },

  topBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 20, paddingTop: 8, paddingBottom: 4,
  },
  topBarRight: { flexDirection: 'row', alignItems: 'center', gap: 8 },

  stopTap:  { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, backgroundColor: '#FF3B3022' },
  stopText: { color: RED, fontWeight: '700', fontSize: 15, fontFamily: 'Inter_700Bold' },

  pill:     { backgroundColor: '#FFFFFF18', borderRadius: 20, paddingHorizontal: 14, paddingVertical: 7 },
  pillText: { color: CREAM, fontWeight: '600', fontSize: 14, fontFamily: 'Inter_700Bold' },

  // Mode toggle pill
  modePill: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: '#FFFFFF14', borderRadius: 20,
    paddingHorizontal: 10, paddingVertical: 6,
  },
  modePillGym: { backgroundColor: 'rgba(0,0,0,0.12)' },
  modePillSegment:           { fontSize: 11, fontWeight: '600', color: MUTED, fontFamily: 'Inter_700Bold' },
  modePillSegmentActive:     { color: CREAM },
  modePillSegmentGymInactive:{ color: 'rgba(0,0,0,0.35)' },
  modePillSegmentGymActive:  { color: '#000' },
  modePillDivider:    { fontSize: 11, color: MUTED, marginHorizontal: 4 },
  modePillDividerGym: { color: 'rgba(0,0,0,0.25)' },

  blockSection:    { minHeight: 190, paddingHorizontal: 28, paddingTop: 24, paddingBottom: 8 },
  blockIndexLabel: { fontSize: 11, fontWeight: '700', color: MUTED, letterSpacing: 2, marginBottom: 10, fontFamily: 'Inter_700Bold' },
  movementText:    { fontSize: 44, fontWeight: '800', color: CREAM, lineHeight: 52, marginBottom: 16, fontFamily: 'Inter_700Bold' },
  tagRow:          { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  tag:             { backgroundColor: '#FFFFFF12', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6 },
  tagText:         { color: '#FFFFFFAA', fontSize: 14, fontWeight: '500', fontFamily: 'Inter_400Regular' },

  // ── Compact timer section ──────────────────────────────────────────────────
  timerSection: {
    flex: 1, alignItems: 'center', justifyContent: 'space-evenly',
    paddingHorizontal: 16, paddingVertical: 4,
  },
  timerDisplay: {
    fontFamily: 'BebasNeue_400Regular',
    fontVariant: ['tabular-nums'],
    color: CREAM,
    includeFontPadding: false,
    textAlign: 'center',
  },
  hrRowBig: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  hrHeartBig: {
    fontFamily: 'BebasNeue_400Regular', color: '#E5484D',
    includeFontPadding: false,
  },
  hrValueBig: {
    fontFamily: 'BebasNeue_400Regular', color: CREAM,
    includeFontPadding: false,
  },
  hrUnitBig: {
    fontSize: 14, color: MUTED, fontFamily: 'Inter_400Regular',
    alignSelf: 'flex-end', paddingBottom: 3,
  },
  gpsSlot:    { minHeight: 52, justifyContent: 'center' as const, alignItems: 'center' as const },
  gpsSlotGym: { height: 50, justifyContent: 'center' as const, alignItems: 'center' as const },
  gpsRowBig: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  gpsSpeedBig: {
    fontFamily: 'BebasNeue_400Regular', color: CREAM,
    includeFontPadding: false,
  },
  gpsUnitBig:  { fontSize: 14, color: MUTED, fontFamily: 'Inter_400Regular' },
  gpsSepBig:   { fontSize: 14, color: MUTED, marginHorizontal: 4 },
  gpsPaceBig:  { fontSize: 16, color: PURPLE, fontFamily: 'Inter_700Bold', fontWeight: '700' },
  bottomSlot:  { alignItems: 'center', minHeight: 32 },
  pausedBadge: { fontSize: 12, fontWeight: '700', color: PURPLE, letterSpacing: 3, fontFamily: 'Inter_700Bold' },
  prevBlock:   { fontSize: 13, color: MUTED, fontWeight: '500', fontFamily: 'Inter_400Regular' },
  hrText:     { fontSize: 16, fontWeight: '600', color: PURPLE, marginTop: 4, fontFamily: 'Inter_700Bold' },
  hrTextGym:  { fontSize: 22, fontWeight: '700', color: 'rgba(0,0,0,0.45)', marginTop: 4, fontFamily: 'Inter_700Bold' },

  progressRow:   { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 24, paddingVertical: 10, gap: 12 },
  progressTrack: { flex: 1, height: 6, backgroundColor: '#FFFFFF1A', borderRadius: 3, overflow: 'hidden' },
  progressFill:  { height: '100%', backgroundColor: GREEN, borderRadius: 3 },
  progressLabel: { fontSize: 12, color: MUTED, fontWeight: '600', minWidth: 44, textAlign: 'right', fontFamily: 'Inter_700Bold' },

  controls:      { paddingHorizontal: 20, paddingBottom: 12, gap: 12 },
  doneBtn:       { backgroundColor: GREEN, borderRadius: 18, height: 80, alignItems: 'center', justifyContent: 'center' },
  doneBtnText:   { color: '#FFF', fontSize: 20, fontWeight: '700', fontFamily: 'Inter_700Bold' },
  pauseBtn:      { backgroundColor: '#FFFFFF14', borderRadius: 18, height: 56, alignItems: 'center', justifyContent: 'center' },
  pauseBtnText:  { color: CREAM, fontSize: 16, fontWeight: '600', fontFamily: 'Inter_700Bold' },
  resumeBtn:     { backgroundColor: PURPLE, borderRadius: 18, height: 80, alignItems: 'center', justifyContent: 'center' },
  resumeBtnText: { color: '#FFF', fontSize: 20, fontWeight: '700', fontFamily: 'Inter_700Bold' },

  // ── Gym mode ──────────────────────────────────────────────────────────────
  safeGym: { flex: 1, backgroundColor: GYM_BG },

  // Floating overlay (absolue, transparent, pas de bandeau)
  gymOverlayTop: {
    position: 'absolute',
    top: 44, // descend sous la barre système même si hidden
    left: 0, right: 0,
    zIndex: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  gymStopFloat: {
    backgroundColor: 'rgba(0,0,0,0.12)',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  gymStopFloatText: { color: '#000', fontWeight: '700', fontSize: 14, fontFamily: 'Inter_700Bold' },
  gymOverlayRight:  { flexDirection: 'row', alignItems: 'center', gap: 8 },
  gymBadgeFloat: {
    backgroundColor: 'rgba(0,0,0,0.12)',
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  gymBadgeFloatText: { color: '#000', fontWeight: '700', fontSize: 13, fontFamily: 'Inter_700Bold' },
  // Elapsed timer — plus grand et lisible de loin
  gymElapsedBadge: {
    backgroundColor: 'rgba(0,0,0,0.18)',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  gymElapsedBadgeText: {
    color: '#000', fontWeight: '800', fontSize: 22,
    fontFamily: 'Inter_700Bold', letterSpacing: -0.5,
  },

  stopTapGym:  { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, backgroundColor: 'rgba(0,0,0,0.15)' },
  stopTextGym: { color: '#000', fontWeight: '700', fontSize: 15, fontFamily: 'Inter_700Bold' },

  pillGym:     { backgroundColor: 'rgba(0,0,0,0.12)', borderRadius: 20, paddingHorizontal: 18, paddingVertical: 9 },
  pillTextGym: { color: '#000', fontWeight: '700', fontSize: 16, fontFamily: 'Inter_700Bold' },

  gymTimerSection: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
    paddingHorizontal: 20,
    paddingTop: 56, // compense l'overlay flottant
  },
  gymTimer: {
    fontSize: 120, fontWeight: '900', color: '#000',
    letterSpacing: -6, fontFamily: 'Inter_700Bold',
    includeFontPadding: false,
    width: '100%', textAlign: 'center',
  },
  gymPausedBadge: {
    fontSize: 12, fontWeight: '700', color: 'rgba(0,0,0,0.45)',
    letterSpacing: 3, marginTop: 10, fontFamily: 'Inter_700Bold',
  },

  gymBlockSection: { minHeight: 150, paddingHorizontal: 28, paddingBottom: 4 },
  gymBlockIndexLabel: {
    fontSize: 13, fontWeight: '700', color: 'rgba(0,0,0,0.5)',
    letterSpacing: 2, marginBottom: 8, fontFamily: 'Inter_700Bold',
  },
  gymMovementText: {
    fontSize: 32, fontWeight: '800', color: '#000',
    lineHeight: 38, marginBottom: 10, fontFamily: 'Inter_700Bold',
  },
  tagGym:     { backgroundColor: 'rgba(0,0,0,0.1)', borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6 },
  tagTextGym: { color: 'rgba(0,0,0,0.65)', fontSize: 14, fontWeight: '500', fontFamily: 'Inter_400Regular' },
  gymPrevBlock: {
    fontSize: 13, color: 'rgba(0,0,0,0.45)', fontWeight: '500',
    marginTop: 8, fontFamily: 'Inter_400Regular',
  },

  progressTrackGym: { flex: 1, height: 6, backgroundColor: 'rgba(0,0,0,0.12)', borderRadius: 3, overflow: 'hidden' },
  progressFillGym:  { height: '100%', backgroundColor: '#000', borderRadius: 3 },
  progressLabelGym: { fontSize: 12, color: 'rgba(0,0,0,0.45)', fontWeight: '600', minWidth: 44, textAlign: 'right', fontFamily: 'Inter_700Bold' },

  doneBtnGym:     { backgroundColor: 'rgba(0,0,0,0.85)', borderRadius: 14, height: 52, alignItems: 'center', justifyContent: 'center' },
  doneBtnTextGym: { color: GYM_BG, fontSize: 16, fontWeight: '700', fontFamily: 'Inter_700Bold' },
  pauseBtnGym:    { backgroundColor: 'rgba(0,0,0,0.1)', borderRadius: 14, height: 40, alignItems: 'center', justifyContent: 'center' },
  pauseBtnTextGym:{ color: 'rgba(0,0,0,0.45)', fontSize: 14, fontWeight: '600', fontFamily: 'Inter_700Bold' },
});

// ── Proposal A extra styles ────────────────────────────────────────────────
const sA = StyleSheet.create({
  // Full screen sans SafeAreaView (évite le bandeau iOS)
  gymFullScreen: {
    flex: 1,
    backgroundColor: GYM_BG,
  },
  // Elapsed stacked au-dessus du timer
  gymElapsedAbove: {
    fontSize: 32, fontWeight: '700', color: 'rgba(0,0,0,0.35)',
    letterSpacing: -1, fontFamily: 'Inter_700Bold',
    marginBottom: 4,
  },
  gymSeparator: {
    width: 48, height: 2, borderRadius: 1,
    backgroundColor: 'rgba(0,0,0,0.15)',
    marginBottom: 8, alignSelf: 'center',
  },
  // Boutons côte à côte
  gymBtnRow: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    paddingBottom: 20,
    gap: 10,
  },
  gymActionBtn: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.88)',
    borderRadius: 14,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  gymActionBtnSmall: { opacity: 0.6 },
  gymActionBtnText: {
    color: GYM_BG, fontSize: 16, fontWeight: '700', fontFamily: 'Inter_700Bold',
  },
  gymPauseBtn: {
    width: 52, height: 52,
    backgroundColor: 'rgba(0,0,0,0.1)',
    borderRadius: 14,
    alignItems: 'center', justifyContent: 'center',
  },
  gymPauseBtnText: {
    fontSize: 22, color: 'rgba(0,0,0,0.4)',
  },
  gymResumeBtn: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.88)',
    borderRadius: 14, height: 52,
    alignItems: 'center', justifyContent: 'center',
  },
  gymResumeBtnText: {
    color: GYM_BG, fontSize: 18, fontWeight: '700', fontFamily: 'Inter_700Bold',
  },
  // Round badge — fond sombre, bien visible
  gymRoundBadge: {
    backgroundColor: 'rgba(0,0,0,0.75)',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 7,
  },
  gymRoundBadgeText: {
    color: GYM_BG, fontWeight: '800', fontSize: 14, fontFamily: 'Inter_700Bold', letterSpacing: 0.5,
  },
});

// ── Countdown styles (partagés compact + gym) ─────────────────────────────
const sCD = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFill,
    backgroundColor: '#E36DAC',
    zIndex: 99,
    alignItems: 'center',
    justifyContent: 'center',
  },
  countText: {
    fontSize: 160,
    fontWeight: '900',
    color: '#000',
    fontFamily: 'Inter_700Bold',
    letterSpacing: -8,
    includeFontPadding: false,
  },
});

// ── GPS Speed styles ──────────────────────────────────────────────────────────
const sGps = StyleSheet.create({
  // Gym mode — sous le chrono central
  row: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    marginTop: 10,
    backgroundColor: 'rgba(0,0,0,0.1)',
    borderRadius: 14, paddingHorizontal: 16, paddingVertical: 8,
  },
  speed: {
    fontSize: 20, fontWeight: '800', color: '#000',
    fontFamily: 'Inter_700Bold', letterSpacing: -0.5,
  },
  sep:  { fontSize: 16, color: 'rgba(0,0,0,0.3)' },
  pace: {
    fontSize: 16, fontWeight: '600', color: 'rgba(0,0,0,0.55)',
    fontFamily: 'Inter_700Bold',
  },

  // Compact mode — sous le chrono
  rowCompact: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    marginTop: 8,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 12, paddingHorizontal: 12, paddingVertical: 6,
    alignSelf: 'center',
  },
  speedCompact: {
    fontSize: 18, fontWeight: '700', color: '#A793AC',
    fontFamily: 'Inter_700Bold', letterSpacing: -0.3,
  },
  sepCompact:  { fontSize: 14, color: 'rgba(255,255,255,0.25)' },
  paceCompact: {
    fontSize: 14, fontWeight: '600', color: '#6B6560',
    fontFamily: 'Inter_700Bold',
  },
});

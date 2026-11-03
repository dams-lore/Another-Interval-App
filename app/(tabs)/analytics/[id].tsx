import React, { useState } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, ScrollView,
  Alert, TextInput, Share, useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter, useLocalSearchParams } from 'expo-router';
import Svg, { Path, Rect, Line, Text as SvgText, Defs, LinearGradient as SvgGrad, Stop } from 'react-native-svg';
import { useSessionStore } from '../../../store/sessionStore';
import { useWorkoutStore } from '../../../store/workoutStore';
import { HrSample } from '../../../types/session';

const GRAD: [string,string,string,string] = ['#f0c4a0','#e8b8c8','#d4b8e0','#c8c0e8'];
const DARK = '#2a1a24';
const MF = 'Manrope_700Bold';
const MR = 'Manrope_400Regular';
const MB = 'Manrope_800ExtraBold';
const g = (a: string) => `rgba(80,40,60,${a})`;

const FORMAT_LABEL: Record<string,string> = { for_time:'For Time', amrap:'AMRAP', intervals:'Intervals' };
const FORMAT_COLOR: Record<string,string> = { for_time:'#7050a0', amrap:'#5a9e57', intervals:'#3a6a94' };

// HR zones Whoop-style
const HR_ZONES = [
  { label: 'Zone 1', min: 0,   max: 114, color: '#6bcfff' },
  { label: 'Zone 2', min: 115, max: 130, color: '#5bdb8a' },
  { label: 'Zone 3', min: 131, max: 145, color: '#f5c842' },
  { label: 'Zone 4', min: 146, max: 162, color: '#f5832e' },
  { label: 'Zone 5', min: 163, max: 999, color: '#e5484d' },
];

function getZone(bpm: number) {
  return HR_ZONES.find(z => bpm >= z.min && bpm <= z.max) ?? HR_ZONES[0];
}

function fmt(s: number) {
  return `${String(Math.floor(s/60)).padStart(2,'0')}:${String(s%60).padStart(2,'0')}`;
}
function fmtShort(s: number) {
  const m = Math.floor(s/60); const sec = s%60;
  return `${m}'${String(sec).padStart(2,'0')}"`;
}
function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('fr-FR',{ weekday:'long', day:'numeric', month:'long' });
}

// ── Courbe HR ──────────────────────────────────────────────────────────────
function HrChart({
  samples, blockResults, workoutSteps, sessionDuration, activeBlock, onBlockPress,
}: {
  samples: HrSample[];
  blockResults: { stepId: string; roundIndex: number; started_at: string; ended_at: string; duration_s: number }[];
  workoutSteps: { id: string; movement: string }[];
  sessionDuration: number;
  activeBlock: number | null;
  onBlockPress: (i: number | null) => void;
}) {
  const { width } = useWindowDimensions();
  const chartW = width - 40;
  const chartH = 120;
  const padL   = 32;
  const padR   = 8;
  const padT   = 8;
  const padB   = 24;
  const innerW = chartW - padL - padR;
  const innerH = chartH - padT - padB;

  if (samples.length < 2) return null;

  const maxT   = sessionDuration;
  const minBpm = Math.max(40, Math.min(...samples.map(s => s.bpm)) - 10);
  const maxBpm = Math.min(220, Math.max(...samples.map(s => s.bpm)) + 10);

  const toX = (t: number)   => padL + (t / maxT) * innerW;
  const toY = (bpm: number) => padT + innerH - ((bpm - minBpm) / (maxBpm - minBpm)) * innerH;

  // Construire le path SVG
  const pts = samples.map(s => `${toX(s.t).toFixed(1)},${toY(s.bpm).toFixed(1)}`);
  const linePath = `M ${pts.join(' L ')}`;
  // Area fill path
  const areaPath = `M ${toX(samples[0].t).toFixed(1)},${(padT + innerH).toFixed(1)} L ${pts.join(' L ')} L ${toX(samples[samples.length-1].t).toFixed(1)},${(padT + innerH).toFixed(1)} Z`;

  // Zones de temps des blocs (depuis les block_results)
  const sessionStart = new Date(blockResults[0]?.started_at ?? 0).getTime();

  // Y-axis labels
  const yLabels = [minBpm, Math.round((minBpm + maxBpm) / 2), maxBpm];

  return (
    <View>
      <Svg width={chartW} height={chartH}>
        <Defs>
          <SvgGrad id="hrGrad" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor="#e5484d" stopOpacity="0.35" />
            <Stop offset="1" stopColor="#e5484d" stopOpacity="0.02" />
          </SvgGrad>
        </Defs>

        {/* Fond surbrillance bloc actif */}
        {activeBlock !== null && blockResults[activeBlock] && (() => {
          const br  = blockResults[activeBlock];
          const brStart = (new Date(br.started_at).getTime() - sessionStart) / 1000;
          const brEnd   = brStart + br.duration_s;
          const x1 = toX(Math.max(0, brStart));
          const x2 = toX(Math.min(maxT, brEnd));
          return (
            <Rect
              x={x1} y={padT} width={x2 - x1} height={innerH}
              fill="rgba(229,72,77,0.13)" rx={4}
            />
          );
        })()}

        {/* Séparateurs de blocs */}
        {blockResults.map((br, i) => {
          const brEnd = (new Date(br.ended_at).getTime() - sessionStart) / 1000;
          const x = toX(Math.min(maxT, brEnd));
          return (
            <Line key={i} x1={x} y1={padT} x2={x} y2={padT + innerH}
              stroke="rgba(255,255,255,0.25)" strokeWidth={1} strokeDasharray="3,3" />
          );
        })}

        {/* Area + line */}
        <Path d={areaPath} fill="url(#hrGrad)" />
        <Path d={linePath} stroke="#e5484d" strokeWidth={2} fill="none" strokeLinecap="round" strokeLinejoin="round" />

        {/* Axe Y */}
        {yLabels.map((v, i) => (
          <SvgText key={i} x={padL - 4} y={toY(v) + 4}
            fontSize={9} fill={g('0.4')} textAnchor="end" fontFamily={MR}>
            {v}
          </SvgText>
        ))}
      </Svg>

      {/* Zones touchables (blocs) sous le chart */}
      <View style={{ flexDirection: 'row', marginTop: 6, paddingLeft: padL, paddingRight: padR }}>
        {blockResults.map((br, i) => {
          const step = workoutSteps.find(st => st.id === br.stepId);
          const isActive = activeBlock === i;
          return (
            <TouchableOpacity
              key={i}
              style={[hrc.blockPill, isActive && hrc.blockPillActive, { flex: br.duration_s }]}
              onPress={() => onBlockPress(isActive ? null : i)}
              activeOpacity={0.75}
            >
              <Text style={[hrc.blockPillText, isActive && hrc.blockPillTextActive]} numberOfLines={1}>
                {step?.movement ?? `B${i+1}`}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

const hrc = StyleSheet.create({
  blockPill:          { backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: 6, marginHorizontal: 1, paddingVertical: 4, alignItems: 'center', minWidth: 0 },
  blockPillActive:    { backgroundColor: 'rgba(229,72,77,0.25)', borderColor: '#e5484d', borderWidth: 1 },
  blockPillText:      { fontSize: 9, color: g('0.5'), fontFamily: MR, textAlign: 'center' },
  blockPillTextActive:{ color: '#e5484d', fontWeight: '700' },
});

// ── Zone breakdown ──────────────────────────────────────────────────────────
function ZoneBreakdown({ samples, totalDuration }: { samples: HrSample[]; totalDuration: number }) {
  const [open, setOpen] = useState(false);
  if (samples.length === 0) return null;

  const zoneTotals = HR_ZONES.map(z => {
    const count = samples.filter(s => s.bpm >= z.min && s.bpm <= z.max).length;
    const secs  = count * 5; // 1 sample = 5 secondes
    return { ...z, secs, pct: Math.round((secs / totalDuration) * 100) };
  }).filter(z => z.secs > 0);

  const avgBpm = Math.round(samples.reduce((a, s) => a + s.bpm, 0) / samples.length);
  const maxBpm = Math.max(...samples.map(s => s.bpm));

  return (
    <View style={zb.container}>
      <TouchableOpacity style={zb.header} onPress={() => setOpen(o => !o)} activeOpacity={0.75}>
        <View style={{ flex: 1 }}>
          <Text style={zb.title}>ZONES CARDIO</Text>
          <Text style={zb.subtitle}>Moy. {avgBpm} bpm · Max {maxBpm} bpm</Text>
        </View>
        <Text style={zb.chevron}>{open ? '▲' : '▼'}</Text>
      </TouchableOpacity>

      {open && (
        <View style={zb.body}>
          {zoneTotals.map((z, i) => (
            <View key={i} style={zb.zoneRow}>
              <View style={[zb.dot, { backgroundColor: z.color }]} />
              <Text style={zb.zoneLabel}>{z.label}</Text>
              <Text style={zb.zoneRange}>{z.min}–{z.max === 999 ? '220' : z.max} bpm</Text>
              <View style={zb.zoneBarTrack}>
                <View style={[zb.zoneBarFill, { width: `${z.pct}%` as any, backgroundColor: z.color }]} />
              </View>
              <Text style={zb.zoneTime}>{fmt(z.secs)}</Text>
              <Text style={zb.zonePct}>{z.pct}%</Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

const zb = StyleSheet.create({
  container: { backgroundColor: 'rgba(255,255,255,0.3)', borderRadius: 18, borderWidth: 1, borderColor: 'rgba(255,255,255,0.5)', marginBottom: 20, overflow: 'hidden' },
  header:    { flexDirection: 'row', alignItems: 'center', padding: 16 },
  title:     { fontSize: 10, fontWeight: '700', color: g('0.5'), letterSpacing: 2, fontFamily: MF },
  subtitle:  { fontSize: 14, fontWeight: '700', color: DARK, marginTop: 2, fontFamily: MF },
  chevron:   { fontSize: 12, color: g('0.4') },
  body:      { paddingHorizontal: 16, paddingBottom: 14, gap: 10 },
  zoneRow:   { flexDirection: 'row', alignItems: 'center', gap: 8 },
  dot:       { width: 8, height: 8, borderRadius: 4 },
  zoneLabel: { fontSize: 12, fontWeight: '700', color: DARK, width: 48, fontFamily: MF },
  zoneRange: { fontSize: 11, color: g('0.4'), width: 72, fontFamily: MR },
  zoneBarTrack: { flex: 1, height: 6, backgroundColor: 'rgba(255,255,255,0.4)', borderRadius: 3, overflow: 'hidden' },
  zoneBarFill:  { height: '100%', borderRadius: 3 },
  zoneTime:  { fontSize: 11, color: DARK, width: 40, textAlign: 'right', fontFamily: MF },
  zonePct:   { fontSize: 11, color: g('0.4'), width: 28, textAlign: 'right', fontFamily: MR },
});

// ── Écran principal ──────────────────────────────────────────────────────────
export default function SessionDetailScreen() {
  const router  = useRouter();
  const { id }  = useLocalSearchParams<{ id: string }>();
  const { sessions, deleteSession } = useSessionStore();
  const { getById, updateWorkout }  = useWorkoutStore();

  const _session = sessions.find(s => s.id === id);
  const workout = _session ? getById(_session.workoutId) : undefined;
  const [editingName, setEditingName] = useState(false);
  const [nameValue, setNameValue]     = useState(_session?.workoutName ?? '');
  const [activeBlock, setActiveBlock] = useState<number | null>(null);

  if (!_session) {
    return (
      <LinearGradient colors={GRAD} locations={[0,0.33,0.66,1]} style={{flex:1}}>
        <SafeAreaView style={{flex:1,alignItems:'center',justifyContent:'center'}}>
          <Text style={{fontSize:16,color:g('0.5'),fontFamily:MR}}>Session introuvable.</Text>
        </SafeAreaView>
      </LinearGradient>
    );
  }

  const session = _session;
  const color = FORMAT_COLOR[session.format] ?? '#7050a0';
  const label = FORMAT_LABEL[session.format] ?? session.format;
  const expectedBlocks = workout ? workout.steps.length * (session.rounds_completed || 1) : null;
  const isPartial = expectedBlocks !== null && session.block_results.length < expectedBlocks;
  const maxDuration = Math.max(...session.block_results.map(b => b.duration_s), 1);
  const maxRound = session.block_results.reduce((m,r) => Math.max(m, r.roundIndex), 0);
  const rounds: typeof session.block_results[] = Array.from({ length: maxRound+1 }, (_,ri) =>
    session.block_results.filter(r => r.roundIndex === ri)
  );

  const hrSamples: HrSample[] = session.hrSamples ?? [];
  const hasHr = hrSamples.length >= 2;

  function handleMenu() {
    Alert.alert(session.workoutName, undefined, [
      { text:'▶  Do it again', onPress: () => router.push(`/workout/${session.workoutId}/run`) },
      { text:'🗑  Supprimer', style:'destructive', onPress: () =>
        Alert.alert('Supprimer ?','Cette action est irréversible.',[
          { text:'Annuler', style:'cancel' },
          { text:'Supprimer', style:'destructive', onPress: () => { deleteSession(session.id); router.back(); } },
        ])
      },
      { text:'Annuler', style:'cancel' },
    ]);
  }

  function saveName() {
    const t = nameValue.trim();
    if (t && t !== session.workoutName && workout) updateWorkout(workout.id, { name: t });
    setEditingName(false);
  }

  async function handleShare() {
    const date = new Date(session.started_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' });
    const lines: string[] = [
      `🏋️ ${nameValue || session.workoutName}`,
      `📅 ${date}`,
      `⏱ ${fmt(session.duration_s)}`,
    ];
    if (session.rounds_completed > 0 && session.format !== 'for_time') {
      lines.push(`🔁 ${session.rounds_completed} round${session.rounds_completed > 1 ? 's' : ''}`);
    }
    lines.push(`📦 ${session.block_results.length} blocs complétés`);
    if (hasHr) {
      const avg = Math.round(hrSamples.reduce((a, s) => a + s.bpm, 0) / hrSamples.length);
      const max = Math.max(...hrSamples.map(s => s.bpm));
      lines.push(`❤️ Cardio moy. ${avg} bpm · max ${max} bpm`);
    }
    lines.push('', 'Entraîné avec AnotherInterval 💪');

    try {
      await Share.share({ message: lines.join('\n') });
    } catch (_) {}
  }

  return (
    <LinearGradient colors={GRAD} locations={[0,0.33,0.66,1]} style={{flex:1}}>
    <SafeAreaView style={{flex:1}} edges={['top','bottom']}>
      {/* Top bar */}
      <View style={s.topBar}>
        <TouchableOpacity style={s.backTap} onPress={() => router.back()}>
          <Text style={s.backText}>← Back</Text>
        </TouchableOpacity>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <TouchableOpacity style={s.shareBtn} onPress={handleShare} activeOpacity={0.75}>
            <Text style={s.shareBtnText}>⬆ Partager</Text>
          </TouchableOpacity>
          <TouchableOpacity style={s.menuBtn} onPress={handleMenu} activeOpacity={0.7}>
            <Text style={s.menuBtnText}>•••</Text>
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView contentContainerStyle={s.content} showsVerticalScrollIndicator={false}>
        {/* Format badge */}
        <View style={[s.badge, { backgroundColor: color+'25', borderColor: color+'45' }]}>
          <Text style={[s.badgeText, { color }]}>{label}</Text>
        </View>

        {/* Title éditable */}
        <View style={s.titleRow}>
          {editingName ? (
            <TextInput style={s.titleInput} value={nameValue} onChangeText={setNameValue}
              autoFocus returnKeyType="done" onSubmitEditing={saveName} onBlur={saveName} />
          ) : (
            <Text style={s.workoutName}>{nameValue || session.workoutName}</Text>
          )}
          <TouchableOpacity style={s.pencilBtn} onPress={() => { setNameValue(session.workoutName); setEditingName(true); }} activeOpacity={0.7}>
            <Text>✏️</Text>
          </TouchableOpacity>
        </View>

        <Text style={s.dateText}>{formatDate(session.started_at)}</Text>

        {isPartial && (
          <View style={s.partialBanner}><Text style={s.partialBannerText}>⚡ Session partielle</Text></View>
        )}

        {/* Stats */}
        <View style={s.statsRow}>
          {[
            { v: fmt(session.duration_s), l: 'Temps' },
            ...(session.format !== 'for_time' ? [{ v: String(session.rounds_completed), l: 'Rounds' }] : []),
            { v: `${session.block_results.length}${expectedBlocks ? `/${expectedBlocks}` : ''}`, l: 'Blocs' },
            { v: session.block_results.length > 0 ? fmtShort(Math.round(session.duration_s / session.block_results.length)) : '—', l: 'Moy.' },
          ].map((item, i, arr) => (
            <React.Fragment key={i}>
              <View style={s.statItem}>
                <Text style={[s.statValue, { color }]}>{item.v}</Text>
                <Text style={s.statLabel}>{item.l}</Text>
              </View>
              {i < arr.length-1 && <View style={s.statDiv} />}
            </React.Fragment>
          ))}
        </View>

        {/* ── Courbe HR ── */}
        <View style={s.hrSection}>
          <Text style={s.sectionTitle}>FRÉQUENCE CARDIAQUE</Text>

          {hasHr ? (
            <>
              <HrChart
                samples={hrSamples}
                blockResults={session.block_results}
                workoutSteps={workout?.steps ?? []}
                sessionDuration={session.duration_s}
                activeBlock={activeBlock}
                onBlockPress={setActiveBlock}
              />
              <ZoneBreakdown samples={hrSamples} totalDuration={session.duration_s} />
            </>
          ) : (
            <View style={s.hrPlaceholder}>
              <Text style={s.hrPlaceholderIcon}>♥</Text>
              <Text style={s.hrPlaceholderTitle}>Connecte une source cardio</Text>
              <Text style={s.hrPlaceholderText}>
                Associe une Garmin, Apple Watch ou capteur BLE pour voir ta courbe ici.
              </Text>
            </View>
          )}
        </View>

        {/* Splits */}
        {session.block_results.length > 0 && (
          <View>
            <Text style={s.sectionTitle}>SPLITS</Text>

            {session.format === 'intervals' ? rounds.map((brs, ri) => (
              <View key={ri} style={s.roundBlock}>
                <View style={s.roundHeader}>
                  <Text style={s.roundLabel}>ROUND {ri+1}</Text>
                  <Text style={s.roundTotal}>{fmt(brs.reduce((a,b) => a+b.duration_s, 0))}</Text>
                </View>
                {brs.map((br, bi) => {
                  const step = workout?.steps.find(st => st.id === br.stepId);
                  const pct  = br.duration_s / maxDuration;
                  return (
                    <View key={bi} style={s.splitRow}>
                      <View style={s.splitTop}>
                        <Text style={s.splitMove} numberOfLines={1}>{step?.movement ?? `Bloc ${bi+1}`}</Text>
                        <Text style={s.splitTime}>{fmtShort(br.duration_s)}</Text>
                      </View>
                      <View style={s.barTrack}>
                        <View style={[s.barFill, { width:`${Math.round(pct*100)}%` as any, backgroundColor: color, opacity: 0.7 - bi*0.05 > 0.3 ? 0.7 - bi*0.05 : 0.3 }]} />
                      </View>
                    </View>
                  );
                })}
              </View>
            )) : session.block_results.map((br, i) => {
              const step = workout?.steps.find(st => st.id === br.stepId);
              const pct  = br.duration_s / maxDuration;
              const isLast = i === session.block_results.length-1;
              return (
                <View key={i} style={[s.splitRow, !isLast && s.splitBorder]}>
                  <View style={s.splitTop}>
                    <View style={{flex:1}}>
                      <Text style={s.splitMove} numberOfLines={1}>{step?.movement ?? `Bloc ${i+1}`}</Text>
                      {step?.type === 'reps'     && <Text style={s.splitSub}>{step.value} reps</Text>}
                      {step?.type === 'distance' && <Text style={s.splitSub}>{step.value} {step.unit}</Text>}
                    </View>
                    <Text style={s.splitTime}>{fmtShort(br.duration_s)}</Text>
                  </View>
                  <View style={s.barTrack}>
                    <View style={[s.barFill, { width:`${Math.round(pct*100)}%` as any, backgroundColor: color }]} />
                  </View>
                </View>
              );
            })}

            {/* Bloc partiel */}
            {isPartial && (() => {
              const last    = session.block_results[session.block_results.length-1];
              const lastIdx = workout?.steps.findIndex(st => st.id === last.stepId) ?? -1;
              const next    = workout?.steps[(lastIdx+1) % (workout?.steps.length ?? 1)];
              if (!next) return null;
              return (
                <View style={[s.splitRow, { opacity: 0.45 }]}>
                  <View style={s.splitTop}>
                    <Text style={s.splitMove}>{next.movement}</Text>
                    <View style={s.partialBadge}><Text style={s.partialBadgeText}>⚡ partiel</Text></View>
                  </View>
                  <View style={s.barTrack}>
                    <View style={[s.barFill, { width:'15%', backgroundColor: g('0.2') }]} />
                  </View>
                </View>
              );
            })()}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
    </LinearGradient>
  );
}

const s = StyleSheet.create({
  topBar:    { flexDirection:'row', alignItems:'center', justifyContent:'space-between', paddingHorizontal:20, paddingVertical:10 },
  backTap:   { paddingVertical:8, paddingRight:16 },
  backText:  { fontSize:15, color:'#7050a0', fontWeight:'600', fontFamily:MF },
  shareBtn:  { paddingHorizontal:14, paddingVertical:8, borderRadius:20, backgroundColor:'rgba(255,255,255,0.35)', borderWidth:1, borderColor:'rgba(255,255,255,0.5)' },
  shareBtnText: { fontSize:13, fontWeight:'700', color:'#7050a0', fontFamily:MF },
  menuBtn:   { padding:10 },
  menuBtnText: { fontSize:18, color:g('0.5'), letterSpacing:2, fontWeight:'700' },
  content:   { paddingHorizontal:20, paddingBottom:48 },
  badge:     { alignSelf:'flex-start', paddingHorizontal:12, paddingVertical:5, borderRadius:20, borderWidth:1, marginBottom:10 },
  badgeText: { fontSize:13, fontWeight:'700', fontFamily:MF },
  titleRow:  { flexDirection:'row', alignItems:'center', gap:10, marginBottom:4 },
  workoutName: { fontSize:26, fontWeight:'800', color:DARK, lineHeight:32, flex:1, fontFamily:MB },
  titleInput:  { fontSize:26, fontWeight:'800', color:DARK, flex:1, fontFamily:MB, borderBottomWidth:2, borderBottomColor:'rgba(112,80,160,0.5)', paddingBottom:2 },
  pencilBtn: { padding:4 },
  dateText:  { fontSize:14, color:g('0.45'), marginBottom:16, fontFamily:MR },
  partialBanner: { backgroundColor:'rgba(255,243,200,0.6)', borderRadius:12, paddingHorizontal:12, paddingVertical:8, marginBottom:16, alignSelf:'flex-start', borderWidth:1, borderColor:'rgba(240,200,60,0.35)' },
  partialBannerText: { fontSize:13, fontWeight:'600', color:'#856404', fontFamily:MF },
  // Stats
  statsRow:  { flexDirection:'row', backgroundColor:'rgba(255,255,255,0.35)', borderRadius:20, borderWidth:1, borderColor:'rgba(255,255,255,0.55)', paddingVertical:16, paddingHorizontal:8, alignItems:'center', marginBottom:24 },
  statItem:  { flex:1, alignItems:'center' },
  statValue: { fontSize:18, fontWeight:'800', letterSpacing:-0.5, fontFamily:MB },
  statLabel: { fontSize:10, color:g('0.4'), marginTop:4, textTransform:'uppercase', letterSpacing:1, fontFamily:MR },
  statDiv:   { width:1, height:28, backgroundColor:'rgba(100,60,80,0.12)' },
  // HR section
  hrSection: { backgroundColor:'rgba(255,255,255,0.3)', borderRadius:18, borderWidth:1, borderColor:'rgba(255,255,255,0.5)', padding:16, marginBottom:24 },
  hrPlaceholder: { alignItems:'center', paddingVertical:24 },
  hrPlaceholderIcon: { fontSize:36, color:'#e5484d', marginBottom:10, opacity:0.4 },
  hrPlaceholderTitle: { fontSize:15, fontWeight:'700', color:DARK, marginBottom:6, fontFamily:MF },
  hrPlaceholderText:  { fontSize:13, color:g('0.45'), textAlign:'center', lineHeight:20, fontFamily:MR },
  // Splits
  sectionTitle: { fontSize:10, fontWeight:'700', color:g('0.45'), letterSpacing:2.5, textTransform:'uppercase', marginBottom:12, fontFamily:MF },
  roundBlock:   { marginBottom:8 },
  roundHeader:  { flexDirection:'row', justifyContent:'space-between', alignItems:'center', paddingVertical:10, borderBottomWidth:1, borderBottomColor:'rgba(255,255,255,0.3)', marginBottom:4 },
  roundLabel:   { fontSize:10, fontWeight:'700', color:g('0.4'), letterSpacing:1.5, fontFamily:MF },
  roundTotal:   { fontSize:14, fontWeight:'700', color:DARK, fontFamily:MF },
  splitRow:     { paddingVertical:12 },
  splitBorder:  { borderBottomWidth:1, borderBottomColor:'rgba(255,255,255,0.3)' },
  splitTop:     { flexDirection:'row', alignItems:'flex-start', justifyContent:'space-between', marginBottom:8 },
  splitMove:    { fontSize:16, fontWeight:'700', color:DARK, flex:1, marginRight:12, fontFamily:MF },
  splitSub:     { fontSize:12, color:g('0.4'), marginTop:2, fontFamily:MR },
  splitTime:    { fontSize:16, fontWeight:'700', color:DARK, fontFamily:MF, minWidth:54, textAlign:'right' },
  barTrack:     { height:6, backgroundColor:'rgba(255,255,255,0.35)', borderRadius:3, overflow:'hidden' },
  barFill:      { height:'100%', borderRadius:3 },
  partialBadge: { backgroundColor:'rgba(255,243,200,0.5)', paddingHorizontal:8, paddingVertical:3, borderRadius:8, borderWidth:1, borderColor:'rgba(240,200,60,0.35)' },
  partialBadgeText: { fontSize:11, fontWeight:'600', color:'#856404', fontFamily:MF },
});

export interface BlockResult {
  stepId: string;
  roundIndex: number;
  started_at: string;
  ended_at: string;
  duration_s: number;
}

export interface HrSample {
  t: number;   // secondes depuis le début de la session
  bpm: number;
}

export interface Session {
  id: string;
  workoutId: string;
  workoutName: string;
  format: string;
  rounds_completed: number;
  started_at: string;
  ended_at: string;
  duration_s: number;
  block_results: BlockResult[];
  hrSamples?: HrSample[];
}

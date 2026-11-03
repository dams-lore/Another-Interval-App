import subprocess
import json
import time

SDK_BIN = r"C:\Users\DamienCOQUET\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin"
SHELL = f"{SDK_BIN}\\shell.exe"

BLOCKS = [
    {"blockName": "400m Run",       "blockType": "run",      "duration": 120, "totalRounds": 4, "targetPace": "4:00"},
    {"blockName": "KB Swings 32kg", "blockType": "for_time", "duration": 60,  "totalRounds": 4, "targetPace": ""},
    {"blockName": "400m Run",       "blockType": "run",      "duration": 120, "totalRounds": 4, "targetPace": "4:00"},
    {"blockName": "Burpees x10",    "blockType": "for_time", "duration": 60,  "totalRounds": 4, "targetPace": ""},
]

def send_state(block, elapsed, round_num, gps_speed=0.0, paused=False):
    payload = {
        "type": "workout_state",
        "blockName": block["blockName"],
        "blockType": block["blockType"],
        "elapsed": elapsed,
        "duration": block["duration"],
        "round": round_num,
        "totalRounds": block["totalRounds"],
        "targetPace": block["targetPace"],
        "gpsSpeed": gps_speed,
        "isPaused": paused
    }
    msg = json.dumps(payload)
    try:
        subprocess.run(
            [SHELL, "send-message", msg],
            capture_output=True, timeout=3
        )
        print(f"[{block['blockName']}] Round {round_num} — {elapsed}s/{block['duration']}s GPS:{gps_speed}")
    except Exception as e:
        print(f"Erreur: {e}")

def run_simulation():
    print("=== Simulation HYROX Breakfast Club ===")
    print("Ctrl+C pour arrêter\n")
    for round_num in range(1, 5):
        print(f"\n--- ROUND {round_num} / 4 ---")
        for block in BLOCKS:
            print(f"\n>> {block['blockName']}")
            for elapsed in range(0, block["duration"] + 1):
                gps = round(14.0 + (elapsed % 10) * 0.1, 1) if block["blockType"] == "run" else 0.0
                send_state(block, elapsed, round_num, gps_speed=gps)
                time.sleep(1)
    print("\n=== Workout terminé ===")

if __name__ == "__main__":
    run_simulation()
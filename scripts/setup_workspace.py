"""Prepare project directories without overwriting existing files."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    for folder in (
        "programs/instruction_tests", "programs/pipeline_tests",
        "programs/benchmarks", "constraints", "build/memory_images",
        "build/simulation", "build/implementation",
    ):
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    print("VLIW workspace ready.")

if __name__ == "__main__":
    main()

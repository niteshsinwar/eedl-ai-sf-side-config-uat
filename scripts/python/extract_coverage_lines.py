import re

log_file = r"C:\Users\NSinwar\.gemini\antigravity\brain\36e72bf6-dddb-4cf5-988c-744b93356776\.system_generated\tasks\task-300.log"
classes = ['AVSTriggerHandler', 'CEE_OpportunityTriggerHandler', 'EducationVerificationHandler', 'TestScoreVerificationHandler']

results = {}
with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        for cls in classes:
            if cls in line and '%' in line and '│' in line:
                # The format is typically: │ ClassName │ 80% │ 10,11,12... │
                parts = line.split('│')
                if len(parts) >= 4:
                    uncovered = parts[3].strip()
                    results[cls] = uncovered

for k, v in results.items():
    print(f"{k} uncovered lines: {v}")

import json
import os
import hashlib
from time import sleep

# Path to dependency map
dependency_json_path = "dependencies.json"

# Load dependency graph
def load_dependencies():
    with open(dependency_json_path, "r", encoding="utf-8") as file:
        return json.load(file)

# Compute file hash to detect changes
def get_file_hash(file_path):
    try:
        with open(file_path, "rb") as f:
            return hashlib.md5(f.read()).hexdigest()
    except FileNotFoundError:
        return None

# Track file states
file_hashes = {}

# Load initial dependencies
dependencies = load_dependencies()

def check_dependencies(changed_file):
    """Checks which files depend on the changed file and ensures they are updated."""
    affected_files = [k for k, v in dependencies.items() if changed_file in v]
    
    if affected_files:
        print(f"WARNING: Changes in {changed_file} require updates to: {affected_files}")
        return affected_files
    return []

print("Tracking file changes...")

while True:
    for file in dependencies:
        current_hash = get_file_hash(file)
        
        if file in file_hashes:
            if file_hashes[file] != current_hash:
                print(f"File changed: {file}")
                affected = check_dependencies(file)
                
                if affected:
                    print(f"ERROR: Update required in {affected} before proceeding!")
                else:
                    print(f"File {file} updated successfully!")
        
        file_hashes[file] = current_hash
    
    sleep(5)

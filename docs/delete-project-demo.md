# Project Deletion Demo

## Overview

The `make delete-project` command provides an interactive way to safely delete project directories from `build/projects/`.

## Usage

```bash
make delete-project
```

## Example Workflow

### 1. Initial Project Listing
```
Current project directories in /home/nextgen/dev/psi-sno/build/projects:
[
    "old-cluster-config",
    "psi-2m7s4",
    "psi-5x5fs",
    "psi-bjvzq",
    "psi-pkfwm",
    "psi-z9jjh",
    "psi-zn4cc",
    "test-project-1",
    "test-project-2"
]
```

### 2. Interactive Selection Menu
```
========================================
PROJECT DELETION MENU
========================================

Available project directories:
1. old-cluster-config
2. psi-2m7s4
3. psi-5x5fs
4. psi-bjvzq
5. psi-pkfwm
6. psi-z9jjh
7. psi-zn4cc
8. test-project-1
9. test-project-2

Enter the number of the project to delete (1-9):
```

### 3. Project Information Display
After selecting a project (e.g., "8" for test-project-1):

```
Selected project: test-project-1
Path: /home/nextgen/dev/psi-sno/build/projects/test-project-1
Size: 4.0K
Last modified: 2024-06-27 17:25:30

Project contains 2 files/directories
Key files found:
[
    "bootstrap.ign",
    "install-config.yaml"
]
```

### 4. Deletion Confirmation
```
========================================
DELETION CONFIRMATION
========================================

You are about to DELETE the following project:

Project Name: test-project-1
Project Path: /home/nextgen/dev/psi-sno/build/projects/test-project-1
Directory Size: 4.0K
Number of Files: 2

⚠️  WARNING: This action cannot be undone! ⚠️

Are you sure you want to delete this project? (yes/no):
```

### 5. Successful Deletion
After confirming with "yes":

```
✅ Project deletion completed successfully!

Deleted project: test-project-1
Former path: /home/nextgen/dev/psi-sno/build/projects/test-project-1
Freed space: 4.0K
Deletion log saved: /home/nextgen/dev/psi-sno/build/projects/.deletion_log_test-project-1_1719511530.yaml

Remaining projects in /home/nextgen/dev/psi-sno/build/projects:
[
    "old-cluster-config",
    "psi-2m7s4",
    "psi-5x5fs",
    "psi-bjvzq",
    "psi-pkfwm",
    "psi-z9jjh",
    "psi-zn4cc",
    "test-project-2"
]
Total remaining projects: 8
```

## Safety Features

### Input Validation
- Only accepts valid numeric input within the range of available projects
- Rejects invalid selections with clear error messages

### Confirmation Required
- Displays comprehensive project information before deletion
- Requires explicit "yes" confirmation
- Cancels operation on any other input

### Audit Trail
- Creates deletion log file with timestamp
- Records project details, deletion time, and user information
- Logs saved as `.deletion_log_<project>_<timestamp>.yaml`

### Verification
- Confirms successful deletion by checking directory no longer exists
- Reports failure if deletion was unsuccessful

## Deletion Log Format

```yaml
Project Deletion Log
====================
deleted_at: '2024-06-27T17:25:30Z'
deleted_by: nextgen
file_count: 2
original_path: /home/nextgen/dev/psi-sno/build/projects/test-project-1
project_name: test-project-1
size: 4.0K
```

## Error Handling

### No Projects Found
```
No project directories found in /home/nextgen/dev/psi-sno/build/projects
```

### Invalid Selection
```
FAILED! => {"msg": "Operation cancelled - invalid selection"}
```

### User Cancellation
```
Operation cancelled by user.
```

### Deletion Failure
```
❌ Project deletion failed!

The directory still exists at: /path/to/project
Please check permissions and try again, or delete manually with:
rm -rf "/path/to/project"
```

## Integration with Makefile

The `delete-project` target is integrated into the main Makefile help system:

```bash
make help
```

Shows:
```
Available targets:
  ...
  delete-project - Interactively delete a project from build/projects/
  ...
```

## Alternative Methods

### Manual Deletion
```bash
# Direct removal (be careful!)
rm -rf build/projects/project-name

# List projects first
ls -la build/projects/
```

### Clean All Projects
```bash
# Remove all build artifacts including projects
make clean
```

## Best Practices

1. **Review Before Deletion**: Always check project contents and size before confirming deletion
2. **Keep Important Projects**: Back up any projects with custom configurations before deletion
3. **Regular Cleanup**: Use this tool regularly to maintain a clean project directory
4. **Check Logs**: Review deletion logs if you need to recover information about deleted projects
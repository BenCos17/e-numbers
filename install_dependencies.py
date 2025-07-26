#!/usr/bin/env python3
"""
Installation script for E-Numbers application dependencies
"""
import subprocess
import sys
import os

def run_command(command):
    """Run a command and return success status"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ {command}")
            return True
        else:
            print(f"✗ {command}")
            print(f"Error: {result.stderr}")
            return False
    except Exception as e:
        print(f"✗ {command}")
        print(f"Exception: {e}")
        return False

def main():
    print("Installing E-Numbers Application Dependencies")
    print("=" * 50)
    
    # Check if requirements.txt exists
    if not os.path.exists('requirements.txt'):
        print("✗ requirements.txt not found!")
        sys.exit(1)
    
    # Install dependencies
    print("Installing Python packages...")
    success = run_command(f"{sys.executable} -m pip install -r requirements.txt")
    
    if success:
        print("\n" + "=" * 50)
        print("✓ All dependencies installed successfully!")
        print("\nTo run the application:")
        print("  python api.py")
        print("\nFor editing capabilities:")
        print("  python api.py --allow-editing")
        print("\nThen open: http://localhost:5000/enumbers.html")
    else:
        print("\n" + "=" * 50)
        print("✗ Installation failed!")
        print("Please check the error messages above and try again.")
        sys.exit(1)

if __name__ == "__main__":
    main() 
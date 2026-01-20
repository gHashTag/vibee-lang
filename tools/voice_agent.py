#!/usr/bin/env python3
"""
VIBEE Terminal Voice Agent v169
φ² + 1/φ² = 3 | PHOENIX = 999

Voice-controlled terminal agent using:
- Whisper (OpenAI) for speech recognition
- pyttsx3 for text-to-speech
- subprocess for terminal commands

Usage:
    python voice_agent.py

Commands:
    "vibee, list files" -> ls -la
    "vibee, go to [dir]" -> cd [dir]
    "vibee, show git status" -> git status
    "vibee, run tests" -> zig test
    "vibee, stop" -> exit
"""

import os
import sys
import subprocess
import re
from typing import Optional, Tuple

# Check dependencies
DEPS_AVAILABLE = True
MISSING_DEPS = []

try:
    import speech_recognition as sr
except ImportError:
    DEPS_AVAILABLE = False
    MISSING_DEPS.append("SpeechRecognition")

try:
    import pyttsx3
except ImportError:
    DEPS_AVAILABLE = False
    MISSING_DEPS.append("pyttsx3")

# Constants
PHI = 1.618033988749895
WAKE_WORD = "vibee"
CONFIDENCE_THRESHOLD = 0.75

# Command patterns
COMMANDS = {
    r"list files?": "ls -la",
    r"show files?": "ls -la",
    r"go to (.+)": "cd {}",
    r"change directory to (.+)": "cd {}",
    r"git status": "git status",
    r"show git status": "git status",
    r"git log": "git log --oneline -10",
    r"git diff": "git diff",
    r"git add all": "git add -A",
    r"git commit": "git commit -m 'Voice commit'",
    r"git push": "git push",
    r"git pull": "git pull",
    r"run tests?": "zig test trinity/output/*.zig 2>&1 | head -20",
    r"build": "cd src/vibeec && zig build",
    r"show directory": "pwd",
    r"where am i": "pwd",
    r"clear": "clear",
    r"help": "echo 'Commands: list files, go to [dir], git status, run tests, stop'",
    r"stop|exit|quit": "__EXIT__",
}


class VoiceAgent:
    """Terminal Voice Agent"""
    
    def __init__(self):
        self.running = False
        self.current_dir = os.getcwd()
        
        if DEPS_AVAILABLE:
            self.recognizer = sr.Recognizer()
            self.engine = pyttsx3.init()
            self.engine.setProperty('rate', 150)
        
    def speak(self, text: str):
        """Synthesize speech"""
        print(f"🔊 {text}")
        if DEPS_AVAILABLE:
            try:
                self.engine.say(text)
                self.engine.runAndWait()
            except Exception as e:
                print(f"TTS error: {e}")
    
    def listen(self) -> Optional[str]:
        """Listen for voice input"""
        if not DEPS_AVAILABLE:
            # Fallback to text input
            try:
                text = input("🎤 Voice (type command): ").strip().lower()
                return text
            except EOFError:
                return None
        
        try:
            with sr.Microphone() as source:
                print("🎤 Listening...")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                audio = self.recognizer.listen(source, timeout=5, phrase_time_limit=10)
            
            text = self.recognizer.recognize_google(audio).lower()
            print(f"📝 Heard: {text}")
            return text
            
        except sr.WaitTimeoutError:
            return None
        except sr.UnknownValueError:
            print("❓ Could not understand")
            return None
        except sr.RequestError as e:
            print(f"❌ Recognition error: {e}")
            return None
        except Exception as e:
            print(f"❌ Error: {e}")
            return None
    
    def parse_command(self, text: str) -> Tuple[Optional[str], Optional[str]]:
        """Parse voice input to terminal command"""
        # Remove wake word
        text = re.sub(rf'^{WAKE_WORD}[,\s]+', '', text)
        
        for pattern, command in COMMANDS.items():
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                if '{}' in command and match.groups():
                    command = command.format(match.group(1))
                return command, text
        
        return None, text
    
    def execute(self, command: str) -> str:
        """Execute terminal command"""
        if command == "__EXIT__":
            self.running = False
            return "Goodbye!"
        
        # Handle cd specially
        if command.startswith("cd "):
            path = command[3:].strip()
            try:
                os.chdir(os.path.expanduser(path))
                self.current_dir = os.getcwd()
                return f"Changed to {self.current_dir}"
            except Exception as e:
                return f"Error: {e}"
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30,
                cwd=self.current_dir
            )
            output = result.stdout or result.stderr
            return output[:500] if output else "Done"
        except subprocess.TimeoutExpired:
            return "Command timed out"
        except Exception as e:
            return f"Error: {e}"
    
    def run(self):
        """Main loop"""
        self.running = True
        
        print("=" * 60)
        print("  VIBEE Terminal Voice Agent v169")
        print("  φ² + 1/φ² = 3 | PHOENIX = 999")
        print("=" * 60)
        print(f"  Wake word: '{WAKE_WORD}'")
        print(f"  Current directory: {self.current_dir}")
        print("  Say 'vibee, help' for commands")
        print("  Say 'vibee, stop' to exit")
        print("=" * 60)
        
        if not DEPS_AVAILABLE:
            print(f"\n⚠️  Missing dependencies: {', '.join(MISSING_DEPS)}")
            print("   Install with: pip install SpeechRecognition pyttsx3 pyaudio")
            print("   Running in TEXT MODE (type commands instead)\n")
        
        self.speak("Voice agent ready")
        
        while self.running:
            text = self.listen()
            
            if not text:
                continue
            
            # Check for wake word
            if WAKE_WORD not in text and DEPS_AVAILABLE:
                continue
            
            command, original = self.parse_command(text)
            
            if command:
                print(f"⚡ Executing: {command}")
                result = self.execute(command)
                print(f"📤 {result}")
                
                # Speak short results
                if len(result) < 100:
                    self.speak(result)
                else:
                    self.speak("Command completed")
            else:
                self.speak(f"Unknown command: {original}")
        
        print("\n👋 Voice agent stopped")


def main():
    """Entry point"""
    agent = VoiceAgent()
    
    try:
        agent.run()
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted")
    

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
VIBEE Browser Agent - Playwright Edition
φ² + 1/φ² = 3 | PHOENIX = 999

Реальный агентный браузер для серфинга
"""

from playwright.sync_api import sync_playwright
import time
import sys

class VIBEEAgent:
    """VIBEE Browser Agent"""
    
    PHI = 1.618033988749895
    PHOENIX = 999
    
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.page = None
        
    def start(self, headless=True):
        """Запуск браузера"""
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(headless=headless)
        self.page = self.browser.new_page()
        print("✅ VIBEE Browser запущен")
        return self
    
    def goto(self, url):
        """Переход на URL"""
        print(f"🌐 Переход: {url}")
        self.page.goto(url, wait_until='domcontentloaded')
        return self
    
    def title(self):
        """Заголовок страницы"""
        return self.page.title()
    
    def url(self):
        """Текущий URL"""
        return self.page.url
    
    def screenshot(self, path='screenshot.png'):
        """Скриншот"""
        self.page.screenshot(path=path)
        print(f"📸 Скриншот: {path}")
        return path
    
    def click(self, selector):
        """Клик по элементу"""
        self.page.click(selector)
        print(f"🖱️ Клик: {selector}")
        return self
    
    def type(self, selector, text):
        """Ввод текста"""
        self.page.fill(selector, text)
        print(f"⌨️ Ввод: {text}")
        return self
    
    def press(self, key):
        """Нажатие клавиши"""
        self.page.keyboard.press(key)
        print(f"⏎ Клавиша: {key}")
        return self
    
    def text(self, selector):
        """Получить текст"""
        return self.page.inner_text(selector)
    
    def html(self):
        """HTML страницы"""
        return self.page.content()
    
    def wait(self, selector, timeout=5000):
        """Ждать элемент"""
        self.page.wait_for_selector(selector, timeout=timeout)
        return self
    
    def eval(self, js):
        """Выполнить JS"""
        return self.page.evaluate(js)
    
    def scroll(self, y=500):
        """Скролл"""
        self.page.evaluate(f'window.scrollBy(0, {y})')
        return self
    
    def back(self):
        """Назад"""
        self.page.go_back()
        return self
    
    def forward(self):
        """Вперёд"""
        self.page.go_forward()
        return self
    
    def close(self):
        """Закрыть"""
        if self.browser:
            self.browser.close()
        if self.playwright:
            self.playwright.stop()
        print("👋 Браузер закрыт")


def demo():
    """Демонстрация VIBEE Agent"""
    print("=" * 60)
    print("  VIBEE Browser Agent - φ² + 1/φ² = 3")
    print("=" * 60)
    
    agent = VIBEEAgent()
    
    try:
        agent.start(headless=True)
        
        # Тест 1: Переход на example.com
        print("\n--- Тест 1: example.com ---")
        agent.goto('https://example.com')
        print(f"📄 Заголовок: {agent.title()}")
        print(f"🔗 URL: {agent.url()}")
        print(f"📝 H1: {agent.text('h1')}")
        agent.screenshot('/tmp/vibee_example.png')
        
        # Тест 2: Переход на Wikipedia
        print("\n--- Тест 2: Wikipedia ---")
        agent.goto('https://en.wikipedia.org')
        print(f"📄 Заголовок: {agent.title()}")
        agent.screenshot('/tmp/vibee_wiki.png')
        
        # Тест 3: Поиск на Wikipedia
        print("\n--- Тест 3: Поиск 'Python' ---")
        agent.type('input[name="search"]', 'Python programming')
        agent.press('Enter')
        time.sleep(2)
        print(f"📄 Заголовок: {agent.title()}")
        print(f"🔗 URL: {agent.url()}")
        agent.screenshot('/tmp/vibee_python.png')
        
        # Тест 4: Скролл
        print("\n--- Тест 4: Скролл ---")
        agent.scroll(500)
        time.sleep(0.5)
        agent.screenshot('/tmp/vibee_scroll.png')
        
        print("\n" + "=" * 60)
        print("✅ Все тесты пройдены!")
        print(f"φ² + 1/φ² = {VIBEEAgent.PHI**2 + 1/VIBEEAgent.PHI**2:.1f}")
        print(f"PHOENIX = {VIBEEAgent.PHOENIX}")
        print("=" * 60)
        
    finally:
        agent.close()


def interactive():
    """Интерактивный режим"""
    print("=" * 60)
    print("  VIBEE Browser Agent - Interactive Mode")
    print("  Команды: goto <url>, click <sel>, type <sel> <text>")
    print("           screenshot, title, url, html, quit")
    print("=" * 60)
    
    agent = VIBEEAgent()
    agent.start(headless=True)
    
    try:
        while True:
            cmd = input("\nVIBEE> ").strip()
            if not cmd:
                continue
            
            parts = cmd.split(maxsplit=2)
            action = parts[0].lower()
            
            try:
                if action == 'quit' or action == 'exit':
                    break
                elif action == 'goto' and len(parts) > 1:
                    agent.goto(parts[1])
                elif action == 'click' and len(parts) > 1:
                    agent.click(parts[1])
                elif action == 'type' and len(parts) > 2:
                    agent.type(parts[1], parts[2])
                elif action == 'screenshot':
                    path = parts[1] if len(parts) > 1 else '/tmp/vibee.png'
                    agent.screenshot(path)
                elif action == 'title':
                    print(f"📄 {agent.title()}")
                elif action == 'url':
                    print(f"🔗 {agent.url()}")
                elif action == 'html':
                    print(agent.html()[:500] + "...")
                elif action == 'scroll':
                    y = int(parts[1]) if len(parts) > 1 else 500
                    agent.scroll(y)
                elif action == 'back':
                    agent.back()
                elif action == 'forward':
                    agent.forward()
                elif action == 'press' and len(parts) > 1:
                    agent.press(parts[1])
                elif action == 'text' and len(parts) > 1:
                    print(f"📝 {agent.text(parts[1])}")
                elif action == 'eval' and len(parts) > 1:
                    result = agent.eval(parts[1])
                    print(f"📊 {result}")
                else:
                    print("❓ Неизвестная команда")
            except Exception as e:
                print(f"❌ Ошибка: {e}")
    finally:
        agent.close()


if __name__ == '__main__':
    if len(sys.argv) > 1:
        if sys.argv[1] == 'demo':
            demo()
        elif sys.argv[1] == 'interactive':
            interactive()
    else:
        print("VIBEE Browser Agent")
        print("Usage:")
        print("  python vibee_agent.py demo        - Демонстрация")
        print("  python vibee_agent.py interactive - Интерактивный режим")

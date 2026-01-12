---
name: devops-deployment
description: DevOps и развертывание
agent: vibe-devops
keywords:
  - devops
  - ci/cd
  - деплой
  - pipeline
  - docker
  - kubernetes
  - opentofu
  - terraform
  - инфраструктура
  - контейнеризация
  - оркестрация
---

## Описание

DevOps практики и развертывание проекта Vibee. Docker контейнеризация, Kubernetes оркестрация, инфраструктура как код через OpenTofu/Terraform.

## Основные возможности

- **Контейнеризация**: Создание и оптимизация Docker образов
- **Kubernetes**: Развертывание и управление в K8s
- **Infrastructure as Code**: Управление инфраструктурой через OpenTofu
- **Мониторинг**: Настройка мониторинга и логирования
- **Безопасность**: Настройка секретов и политик безопасности

## Примеры использования

- Создание Dockerfile для проекта
- Настройка Kubernetes deployment для Vibee
- Управление инфраструктурой через OpenTofu
- Настройка мониторинга и алертов
- Настройка секретов через Infisical

## Связанные скиллы

- `cicd-pipeline` - автоматизация деплоя
- `monitoring-sentry` - мониторинг приложения
- `security-audit` - безопасность инфраструктуры

## Best Practices

- Используй multi-stage Docker builds для оптимизации
- Настраивай health checks для всех сервисов
- Управляй секретами через внешние системы (Infisical)
- Используй Infrastructure as Code для воспроизводимости
- Настраивай автоматический rollback при ошибках деплоя
- Мониторь использование ресурсов и оптимизируй

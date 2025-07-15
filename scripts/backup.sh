#!/bin/bash

# Скрипт резервного копирования

BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="voip-platform-backup-$DATE"

echo "Creating backup: $BACKUP_NAME"

# Создаем директорию для бэкапов
mkdir -p $BACKUP_DIR

# Создаем архив
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='data/logs/*' \
    --exclude='volumes/*' \
    --exclude='backups/*' \
    --exclude='.git/*' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    .

echo "Backup created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Удаляем старые бэкапы (старше 7 дней)
find $BACKUP_DIR -name "voip-platform-backup-*.tar.gz" -mtime +7 -delete

echo "Old backups cleaned up"
echo "Backup completed successfully!"
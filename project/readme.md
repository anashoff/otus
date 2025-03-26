Выполните:

```bash
ansible-galaxy install -r requirements.yml
```

Создайте vars.yml для секретов:

```yaml
telegram_bot_token: "YOUR_BOT_TOKEN"
telegram_chat_id: "YOUR_CHAT_ID"
```

Запустите плейбук:

```bash
ansible-playbook -i inventory.ini deploy_stack.yml --extra-vars "@vars.yml"
```

Примечания:

Убедитесь, что пути к логам Angie (/var/log/angie/) и MariaDB (/var/log/mysql/) корректны.

Настройте фаервол для разрешения трафика между узлами.

Для тестирования алертов можно остановить службу Node Exporter на любой ноде.


# Discord Webhook Bash Script

This is a bash script for sending messages to a Discord channel using a webhook. It can send a simple message or a file. The script can be used in another script to send a message when a condition is met, or in a cron job to send a message at a specific time.

## Dependencies

The script depends on the following utilities:

- curl
- grep
- head
- cut
- sed

Please ensure these are installed on your system before running the script.

## Usage

```sh
./discord_webhook.sh [OPTIONS]
```

### Options

- `-w <webhook_url> OR <path/to/file>`: Specify the webhook URL directly or via a file.
- `-u <username>`: Specify the username.
- `-m <message>`: Specify the message.
- `-t <title>`: Specify the title.
- `-d <description>`: Specify the description.
- `-a <avatar_url>`: Specify the avatar URL.
- `-c <#color_hex>`: Specify the color in hex format.
- `-f <path/to/file>`: Specify the path to the file.
- `-h`: Show the usage and exit.

### Notes

- If the `-w` option is not specified, the script will read the webhook URL from `$HOME/.discord_webhook` or the `DISCORD_WEBHOOK_URL` environment variable.
- You must specify at least `-m`, `-t`, `-d` or `-f`.
- If `-f` is used, `-m`, `-t` and `-d` will be ignored.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE) file for details.

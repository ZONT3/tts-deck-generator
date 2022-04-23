import os.path
from argparse import ArgumentParser
from datetime import datetime

import discord

time_format = '%d/%m/%y %H:%M:%S'

if __name__ == '__main__':
    p = ArgumentParser()
    p.add_argument('token', type=str, help='Bot token')
    p.add_argument('guild_id', type=int, help='Target guild id')
    p.add_argument('channel_id', type=int, help='Target channel id')
    p.add_argument('timestamp', type=str, help=f'Timestamp after which scrap messages, in format {time_format}')
    p.add_argument('-o', '--output', type=str, default='output', help=f'Output dir')

    args = p.parse_args()

    client = discord.Client()

    @client.event
    async def on_ready():
        try:
            guild = client.get_guild(args.guild_id)
            channel = guild.get_channel(args.channel_id)
            print('Channel found: ' + str(channel))

            msg: discord.Message
            async for msg in channel.history(after=datetime.strptime(args.timestamp, time_format)):
                if hasattr(msg, 'attachments') and len(msg.attachments) > 0:
                    print(f'Msg attachements: {len(msg.attachments)}... ', end='')
                    for i, a in enumerate(msg.attachments):
                        ext = a.filename.lower().split(".")[-1]
                        if ext not in ['png', 'jpg', 'jpeg']:
                            continue
                        if len(msg.attachments) == 1 and msg.content and len(msg.content) > 0:
                            name = f'{msg.content}.{ext}'
                        else:
                            name = f'[{msg.id}00{i}] {a.filename}'

                        await a.save(os.path.join(args.output, name))
                    print('saved.')
                else:
                    print(f'Not found attachments')

        except Exception as e:
            print(e)

    client.run(args.token)

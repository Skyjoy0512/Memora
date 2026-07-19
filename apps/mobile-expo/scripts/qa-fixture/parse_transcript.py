#!/usr/bin/env python3
"""PLAUD形式の文字起こし(HH:MM:SS Speaker N + 本文行)を時刻付きセグメントJSONへ変換する。

usage: parse_transcript.py <transcript.txt> <audio_duration_seconds> <out.json>
"""
import json
import re
import sys

PATTERN = re.compile(r'^(\d{1,2}):(\d{2}):(\d{2})\s+(.+?)\s*$')


def parse(path: str, duration: float):
    segments = []
    for line in open(path, encoding='utf-8').read().splitlines():
        matched = PATTERN.match(line)
        if matched:
            hours, minutes, seconds, speaker = matched.groups()
            start = int(hours) * 3600 + int(minutes) * 60 + int(seconds)
            segments.append({'start': start, 'speaker': speaker.strip(), 'text': ''})
        elif segments and line.strip():
            joiner = '' if not segments[-1]['text'] else ' '
            segments[-1]['text'] += joiner + line.strip()

    for index, segment in enumerate(segments):
        following = segments[index + 1]['start'] if index + 1 < len(segments) else duration
        segment['end'] = following
    return [s for s in segments if s['text']]


def main():
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    segments = parse(sys.argv[1], float(sys.argv[2]))
    json.dump(segments, open(sys.argv[3], 'w'), ensure_ascii=False)
    speakers = sorted({s['speaker'] for s in segments})
    print(f'segments={len(segments)} speakers={len(speakers)} last_start={segments[-1]["start"]}s')
    return 0


if __name__ == '__main__':
    sys.exit(main())

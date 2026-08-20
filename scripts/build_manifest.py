#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations
import hashlib,json
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];DB=ROOT/'Database';OUT=DB/'HB2024_数据库清单.json'
folders=[];all_files=[]
for d in sorted(x for x in DB.iterdir() if x.is_dir()):
 files=sorted(p for p in d.rglob('*') if p.is_file())
 entries=[]
 for p in files:
  h=hashlib.sha256(p.read_bytes()).hexdigest()
  rel=str(p.relative_to(DB)).replace('\\','/')
  entries.append({'路径':rel,'大小字节':p.stat().st_size,'SHA256':h})
  all_files.append(entries[-1])
 folders.append({'目录':d.name,'文件数':len(entries),'大小字节':sum(x['大小字节'] for x in entries)})
payload={'数据库版本':'HB2024-JSON-R1-20260820','生成时间UTC':datetime.now(timezone.utc).isoformat(timespec='seconds'),'说明':'本清单用于本地一键同步后的版本核验；数据库更新采用先备份、后覆盖且不删除本地已有文件的策略。','目录汇总':folders,'文件总数':len(all_files),'总大小字节':sum(x['大小字节'] for x in all_files),'文件':all_files}
OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'文件总数':payload['文件总数'],'总大小字节':payload['总大小字节'],'输出':str(OUT)},ensure_ascii=False))

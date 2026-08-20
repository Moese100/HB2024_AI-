#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""无清单编码时的JSON定额候选检索器。

示例：
python3 无编码清单候选检索.py --name 塑料管 --feature '室内给水 PPR DN50 热熔' --unit m
"""
from __future__ import annotations
import argparse,json,re
from pathlib import Path

INDEX=Path('/home/ubuntu/working/湖北2024定额库_统一索引/全专业定额检索索引.jsonl')
STOP=set('工程安装制作敷设项目相应以内以上以下及其按设计图示尺寸材料规格型号名称部位管道设备构件混凝土施工')

def norm(s):
 s=str(s or '').lower().replace('㎡','m2').replace('㎥','m3').replace('³','3').replace('²','2').replace('φ','dn').replace('ø','dn')
 return re.sub(r'[^\u4e00-\u9fffA-Za-z0-9≤≥<>.+×x-]','',s)
def unit_base(s):
 s=norm(s);m=re.fullmatch(r'\d+(?:\.\d+)?(.+)',s)
 return m.group(1) if m else s
def terms(s):
 text=norm(s)
 chinese=set(c for c in text if '\u4e00'<=c<='\u9fff' and c not in STOP)
 words=set(re.findall(r'[a-z]+\d*|dn\d+|\d+(?:\.\d+)?(?:mm|m2|m3|m|kv|kw)?',text))
 return chinese|words
def specs(s):
 s=norm(s)
 values=set(re.findall(r'dn\d+|\d+(?:\.\d+)?(?:mm|m2|m3|kv|kw)',s))
 # DN50与“公称外径50mm”属于同一规格线索，额外保留裸数值用于跨写法匹配。
 for value in list(values):
  match=re.fullmatch(r'dn(\d+)',value)
  if match: values.add(match.group(1))
 return values
def route_hint(text):
 text=norm(text)
 patterns=[
  ('C10',['给水','排水','污水','雨水','阀门','水表','卫生器具','地漏','水泵','ppr','pe','pvc']),
  ('C4',['配电','电缆','灯具','插座','开关','桥架','接地','配管']),
  ('C7',['通风','风管','风机','空调']),('C9',['消防','喷淋','消火栓','火灾报警']),
  ('A2',['基础','柱','梁','板','混凝土','钢筋']),('A16',['模板','支撑']),
 ]
 return next((p for p,keys in patterns if any(k in text for k in keys)),None)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--name',required=True);ap.add_argument('--feature',default='');ap.add_argument('--unit',default='');ap.add_argument('--top',type=int,default=10);args=ap.parse_args()
 query=args.name+' '+args.feature; qt=terms(query);qs=specs(query);hint=route_hint(query)
 rows=[json.loads(x) for x in INDEX.read_text(encoding='utf-8').splitlines() if x]
 scored=[]
 for r in rows:
  code=r['定额子目编码'];name=r['定额名称']; rt=terms(name); rs=specs(name);score=0
  if norm(args.name) and norm(args.name) in norm(name):score+=45
  if qt and rt:score+=40*len(qt&rt)/max(1,len(qt|rt))
  if args.unit and unit_base(args.unit)==unit_base(r['单位']):score+=28
  if qs and rs:score+=20*len(qs&rs)/max(1,len(qs|rs))
  # 无编码时，部位、介质和连接方式属于高优先级条件，不能只靠字符重合。
  for condition in ['室内','室外','热熔','法兰','螺纹','焊接']:
   if condition in norm(query) and condition in norm(name): score+=12
  if '给水' in norm(query) and any(x in norm(name) for x in ['雨水','排水','污水']): score-=32
  if '雨水' in norm(query) and '给水' in norm(name): score-=32
  if hint and code.startswith(hint+'-'):score+=18
  if score>=12:scored.append((round(score,2),r))
 scored.sort(key=lambda x:x[0],reverse=True)
 out=[]
 for i,(score,r) in enumerate(scored[:args.top],1):
  out.append({'序号':i,'评分':score,'定额子目编码':r['定额子目编码'],'定额名称':r['定额名称'],'单位':r['单位'],'册':r['册'],'章':r['章'],'建议复核':True})
 print(json.dumps({'输入':{'项目名称':args.name,'项目特征':args.feature,'单位':args.unit},'专业路由提示':hint or '未确定','候选':out},ensure_ascii=False,indent=2))
if __name__=='__main__':main()

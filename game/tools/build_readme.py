# -*- coding: utf-8 -*-
import os
os.makedirs('/data/build', exist_ok=True)
README = r"""寂静岭同人 · 雾中回响  (Silent Hill Fan Demo — Echoes in the Fog)
================================================================
非官方同人作品 · 与 KONAMI 无关 · 仅供学习交流，请勿商用。
「寂静岭 / Silent Hill」为 KONAMI 的注册商标。本作未使用任何原作美术、音乐或音效素材。

【如何运行】
1. 解压整个文件夹（不要在压缩包里直接运行）。
2. 双击 SH_FogEcho.exe。
3. 如果出现黑屏、闪退或提示 Vulkan 错误（老显卡 / 核显较常见），
   请改为双击 Compatibility_Mode_OpenGL.bat（OpenGL 兼容模式，画质较低、无体积雾）。
4. 卡顿时：Esc → 设置 → 画质 选「低」，渲染分辨率选 75% 或 50%。

推荐配置：Windows 10/11 64 位，支持 Vulkan 的独立显卡（GTX 1050 / RX 560 及以上）。
建议戴耳机，在关灯的房间里游玩。流程约 15～25 分钟。

【操作】
WASD 移动　　Shift 奔跑（消耗体力）　　鼠标 环顾
E 调查 / 拾取 / 阅读　　F 手电筒　　鼠标左键 攻击（倒地的敌人：靠近再按左键＝踩踏）
Tab 物品栏（可使用回复道具、查看文件）　　M 地图　　R 收音机开关　　Esc 暂停 / 设置
手柄：左摇杆移动，右摇杆视角，A 调查，X 攻击，Y 手电筒，Start 暂停。

【提示】
· 收音机的杂音越响，怪物就越近。
· 奔跑和手电筒都会让你更容易被发现。
· 被打倒的怪物还会爬起来——一定要补上几脚。
· 怪物胸口的裂口张开、发出咕噜声时，快躲开：它会吐出腐蚀性的酸液，站在酸液里会持续受伤。
· 路上躺着的“尸体”，不一定真的死了。
· 地图上的红色标记会提示下一步去哪里。
· 游戏会在关键地点自动记录进度（画面右下角提示），死亡后可从最近的记录点重来。
  存档位置：%APPDATA%\SH_FogEcho\

【故事】
那天夜里，你开车带着女儿「小雪」前往寂静岭度假。车灯里突然闪过一个人影——
醒来时，车撞在路边，四周全是浓雾，副驾驶座上空无一人……

【v1.1 更新】
· 全新怪物：重新雕刻的“躺尸”型血肉怪（胸口竖裂的獠牙口、皮下蠕动的双臂、断颈歪头），
  骨骼动画：瘸腿拖行、脊椎扭动、头部高速乱颤、全身痉挛（骨裂声）、僵直起身、死亡抽搐喷血。
· 新攻击：胸口裂口喷吐腐蚀酸液（远程），酸液落地会冒烟并持续灼伤。
· 新惊吓：雾中伫立的人影、路边装死的“尸体”伏击；全新 CC0 怪物音效。

【素材与授权】
· 引擎：Godot Engine 4.3（MIT）
· 贴图：Poly Haven、ambientCG（CC0），部分为程序生成
· 模型：Kenney（CC0）及程序生成几何体；怪物为程序雕刻（SDF 建模 + 自动蒙皮 + 程序骨骼动画）
· 音效 / 音乐：程序合成 + 重新混音的 CC0 录音——Freesound（cocaine、Kostrava、audiojacked、
  harveyjnz、cognito perceptu、Lewente、Poligonstudio、Resaural、RutgerMuller；
  怪物音效：MrPokephile、jasonLON、marlonnnnnn、JadeW40、Wakerone、scorpion67890、gpag1、
  iut_Paris8、MSEpitaph、adharca、lolamadeus、Firestorm002、ericnorcross81、danielrutterfilms、
  1urker、ProductionNow、deoking、ThefitzyG、brlproductions、ErikH2000、bottles、spookymodem、
  SpliceSound、Podsburgh）与 Kenney 音效包；全部为 CC0，来源清单见源码包 tools/fs2_credits.json；
  无任何原作音频
· 字体：思源宋体 / Noto Serif CJK（SIL OFL 1.1）、霞鹜文楷（SIL OFL 1.1）
· 美术风格与剧情结构致敬《寂静岭》系列（KONAMI），仅为爱好者创作。
"""
open('/data/build/README.txt','w',encoding='utf-8-sig',newline='\r\n').write(README)
BAT = '@echo off\r\ncd /d "%~dp0"\r\nstart "" "SH_FogEcho.exe" --rendering-method gl_compatibility --rendering-driver opengl3\r\n'
open('/data/build/Compatibility_Mode_OpenGL.bat','w',encoding='ascii',newline='').write(BAT)
print('ok')

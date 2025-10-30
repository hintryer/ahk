; 脚本功能：根据AHK语法自动调整代码缩进和命令大小写
; 作者：toralf & hajos
; 依赖：需AHK 1.0.44.09及以上版本
; 原论坛链接：www.autohotkey.com/forum/topic7810.html

; 脚本版本与名称定义
Version = v13
ScriptName =  Auto-Syntax-Tidy %Version%

; 已知限制说明（使用时需注意的边界情况）
; 1. 热键、热字符串和子程序的最后一个":"后必须有空格
; 2. 在某些强封装的代码块结构中，注释缩进可能不准确（因无法预知下一行内容）
; 3. 大小写纠正仅对4个字符以上的单词生效，以下单词例外：
;    - 强制生效：If、Loop、Else
;    - 可选生效：Goto、Gui、Run、Exit、Send等（见后续配置）
;    - 警告：大小写纠正有风险，因命令中的窗口标题（WinTitle）对大小写敏感
; 4. 在编辑器中执行缩进后，光标会跳转到最后一行的起始位置
; 5. 若Loop/If语句不支持"一行块"（OTB）且"{"是最后一个字符（如"If x = {"），缩进可能失败

; 核心功能清单
; 1. 图形界面（Gui）：支持文件拖放、选项设置和操作反馈
; 2. 命令行参数：
;    - /in：指定待处理文件
;    - /log：指定日志文件
;    - /hidden：启动时隐藏Gui
;    - /watch hwnd：隐藏Gui，且目标窗口（hwnd）关闭时脚本自动退出
;    - /toggle：检查是否有其他实例运行，若有则关闭所有实例
; 3. 可配置选项：
;    - 自定义缩进热键
;    - 自定义文件扩展名（未指定则覆盖原文件）
;    - 自定义缩进方式（1个制表符或多个空格）
;    - 三种缩进风格（Rajat、Toralf、BoBo）
;    - 续行缩进（制表符/空格数量）
;    - 保留代码块续行（圆括号）和块注释（/*...*/）的缩进（开/关）
;    - 语法单词大小写纠正（4字符以上，感谢Rajat）
;    - 脚本统计（代码行数、注释行数、总行数、处理时间）
; 4. 文件处理：拖放的文件会被缩进并保存为新文件（按自定义扩展名）
; 5. 编辑器集成：热键（默认F2）缩进选中内容，无选中则缩进全部文本（感谢ChrisM）
; 6. 配置记忆：Gui会记住上一次的位置和设置（感谢Rajat）
; 7. 大小写同步：子程序调用和函数调用的大小写会与定义处同步
; 8. 调试模式：Ctrl+D切换调试模式
; 9. 性能优化：比v7版本快12%（缩短循环周期），但代码增加90行

; 警告：未经过充分测试，使用前务必备份数据！
; 功能需求：支持代码精简（移除空行、所有注释、合并拆分表达式）

; 版本更新日志（自v11起）
/*
v11后更新：
1. 托盘图标支持切换Gui显示/隐藏和退出脚本
2. 在编辑器中执行缩进且启用输入阻塞（BlockInput）时，添加进度条（减少干扰）
3. 用函数简化代码，新增功能后保持代码行数稳定
4. 日志文本自动滚动到末尾
5. /hidden参数启动时，Gui创建但隐藏，托盘图标始终可见
6. /watch hwnd参数启动时，Gui隐藏且目标窗口关闭时脚本退出
7. /toggle参数支持检查多实例并关闭所有实例
8. 优化AHK路径查找逻辑
9. 若语法文件不存在，弹出警告提示
10. 自定义热键（OwnHotKey）保存到INI文件，且在Gui中可控制

2013.11.21 修复与优化：
- 将AHKPath固定为脚本目录，语法文件目录设为%AHKPath%\Syntax（修复bug #1）
- 合并最新SCITE4AHK的ahk.api文件与1.0.48.5语法文件
- 保留已移除的旧命令（如REPEAT），确保格式化正常工作
- 默认关闭KEYWORDS大小写纠正（修复bug #2：避免DLLCALL函数名被错误纠正，因DLLCALL对大小写敏感）

2013.11.22 功能优化：
- 修改代码，运行时直接格式化选中内容或全部代码

2014.03.06 功能新增：
- 支持for语句的格式化（feature #1）

2014.03.07 修复与优化：
- 支持中文函数名格式化（修复bug #3）
- 修改默认格式化风格
- 支持While、Until、Try、Catch、Finally语句格式化（feature #1）

2014.03.15 逻辑修复：
- Until后面的语句不缩进

2014.03.26 大小写优化：
- 以下单词强制纠正为全小写（feature #2）：if、else、goto

2016.04.23 大小写优化：
- loop单词强制纠正为全小写（feature #2）

2020.09.01 严重bug修复：
- 修复丢失"++num"这类行的恶性bug（bug #4）
- 处理剪贴板操作可能出现的bug（bug #5）
- 函数后的花括号（仅花括号本身）不缩进（feature #3）
- 版本号更新为v13

2020.09.03 功能新增与修复：
- 支持switch、class语句格式化（feature #1）
- 大小写纠正分级（从低到高）：Keywords < Keys < Variables < CommandNames < ListOfDirectives
  （低级与高级单词重复时，高级覆盖低级，如Keys的"click"会被CommandNames的"Click"覆盖，feature #4）
- 修复Variables列表的纠正逻辑（bug #6）
- 更新语法文件

2021.01.16 风险控制：
- 屏蔽Gui中的Keywords选项，避免其被使用（防止DllCall内单词被错误纠正导致代码失效）

2021.05.05 大小写修复：
- 纠正大小写时采用"全字匹配"（如DllCall("XCGUI\XRunXCGUI")不会被错误处理，bug #7）

2021.11.01 基础更新：
- 更新语法文件
*/

; 单实例运行（重复启动时忽略新实例）
#SingleInstance ignore
; 最大化脚本运行速度（禁用批处理行延迟）
SetBatchLines, -1

; 设置工作目录为脚本所在目录（避免从其他目录调用时路径错误）
SetWorkingDir, %A_ScriptDir%
/*
; 处理命令行参数（作者：Ace_NoOne，原链接：www.autohotkey.com/forum/viewtopic.php?t=7556）
If %0%{ ; 若存在命令行参数
	Loop, %0% { ; 遍历所有参数
		next := A_Index + 1 ; 获取下一个参数的索引
		; 判断参数类型并赋值
		If (%A_Index% = "/in")
			param_in := %next% ; /in：待处理文件路径
		Else If (%A_Index% = "/log")
			param_log := %next% ; /log：日志文件路径
		Else If (%A_Index% = "/hidden")
			param_hidden = Hide ; /hidden：隐藏Gui启动
		Else If (%A_Index% = "/watch"){
			param_hidden = Hide ; /watch：隐藏Gui
			param_watch := %next% ; 目标窗口句柄（hwnd）
		}Else If (%A_Index% = "/Toggle")
			Gosub, CheckAndToggleRunState ; /toggle：检查多实例并关闭
	}
}
*/

; 调试模式开关（0=关闭，1=开启，开启后会弹出调试信息）
DebugMode = 0

; 托盘图标文件路径（根据系统版本选择）
If ( A_OSType = "WIN32_WINDOWS" )  ; Windows 9x系统
	IconFile = %A_WinDir%\system\shell32.dll
Else ; Windows NT/XP及以上系统
	IconFile = %A_WinDir%\system32\shell32.dll

/*
; 配置托盘菜单
Menu, Tray, Icon, %IconFile%, 56   ; 设置托盘图标（使用shell32.dll中的第56个图标）
Menu, Tray, Tip, %ScriptName%      ; 托盘提示文本（脚本名称）
Menu, Tray, NoStandard             ; 禁用默认托盘菜单
Menu, Tray, Add, Show/Hide, ShowHideGui ; 添加"显示/隐藏"菜单项（触发ShowHideGui标签）
Menu, Tray, Add, Exit, ExitApp     ; 添加"退出"菜单项（触发ExitApp命令）
Menu, Tray, Default, Show/Hide     ; 设置"显示/隐藏"为默认菜单项
Menu, Tray, Click, 1               ; 单击托盘图标触发默认菜单项
*/

; 拆分脚本文件名（获取无扩展名的文件名，用于INI配置文件命名）
SplitPath, A_ScriptName, , , , OutNameNoExt
IniFile = %OutNameNoExt%.ini ; INI配置文件路径（与脚本同目录，同名）
Gosub, ReadDataFromIni ; 读取INI配置文件中的设置（跳转至ReadDataFromIni标签）


; 查找AHK路径（固定为脚本目录，语法文件目录随之固定，修复bug #1）
AHKPath:=A_ScriptDir
; 若脚本目录不存在，弹出错误提示并退出
IfNotExist %AHKPath%
{ MsgBox,,, Could not find the AutoHotkey folder.`nPlease edit the script:`n%A_ScriptFullPath%`nin Linenumber: %A_LineNumber%
	ExitApp
}

; 读取语法文件（跳转至ReadSyntaxFiles标签，加载命令、关键词等语法规则）
Gosub, ReadSyntaxFiles
/*
; 若通过命令行指定了待处理文件，执行文件缩进并退出
If FileExist(param_in){
	Gosub, IndentFile ; 跳转至IndentFile标签（处理指定文件）
	ExitApp
}

; 构建Gui界面（跳转至BuildGui标签）
Gosub, BuildGui

; 若通过命令行指定了/watch参数，启动窗口监控定时器
If param_watch
	SetTimer, WatchWindow, On
*/
; 执行选中内容的缩进（跳转至IndentHighlightedText标签）
Gosub,IndentHighlightedText
ExitApp ; 退出脚本
Return ; 结束自动执行段（AutoExec Section）
/*
; 在脚本自身的Gui中禁用缩进热键（避免在设置界面误触发）
Hotkey, IfWinNotActive, %GuiUniqueID%
; 设置缩进热键并记录旧热键
Hotkey, %OwnHotKey%, IndentHighlightedText
OldHtk = %OwnHotKey%
Hotkey, IfWinNotActive,
Return
*/
;#############   自动执行段结束   ####################################

;#############   调试模式切换（Ctrl+D）   #########################################
^d::
	DebugMode := not DebugMode ; 切换调试模式（0→1或1→0）
	ToolTip, DebugMode = %DebugMode% ; 显示当前调试模式状态
	Sleep, 1000 ; 显示1秒
	ToolTip ; 隐藏提示框
Return

;#############   窗口监控（/watch参数）：目标窗口关闭时脚本退出   ###############
WatchWindow:
	DetectHiddenWindows, On ; 检测隐藏窗口
	; 若目标窗口（hwnd）不存在，执行Gui关闭逻辑
	If !WinExist("ahk_id " param_watch)
		Gosub, GuiClose ; 跳转至GuiClose标签（保存配置并退出）
	DetectHiddenWindows, Off ; 关闭隐藏窗口检测
Return

;#############   实例状态切换（/toggle参数）：第二次运行时关闭所有实例   ####################
CheckAndToggleRunState:
	; 获取当前脚本的进程ID（PID）
	Process, Exist
	OwnPID := ErrorLevel

	; 获取当前脚本的窗口标题（区分编译版与未编译版）
	If A_IsCompiled
		OwnTitle := A_ScriptFullPath ; 编译版：标题为脚本完整路径
	Else
		OwnTitle := A_ScriptFullPath " - AutoHotkey v" A_AhkVersion ; 未编译版：标题含AHK版本

	; 获取所有窗口列表
	DetectHiddenWindows, On
	WinGet, WinIDs, List

	; 遍历所有窗口，查找相同标题的其他实例
	Loop, %WinIDs% {
		UniqueID := "ahk_id " WinIDs%A_Index%
		WinGetTitle, winTitle, %UniqueID%

		; 若找到相同标题但不同PID的窗口（其他实例）
		If (winTitle = OwnTitle ) {
			WinGet, winPID, PID, %UniqueID%
			If (winPID <> OwnPID) {
				; 关闭其他实例和当前实例
				Process, Close, %winPID%
				ExitApp
			}
		}
	}
	DetectHiddenWindows, off
Return

;#############   从语法文件读取指令和命令   ##############
ReadSyntaxFiles:
	; 语法文件路径（脚本目录下的Syntax子目录，修复bug #1）
	PathSyntaxFiles = %AHKPath%\Syntax

	; 清空语法列表（初始化）
	ListOfDirectives =
	; 流程控制命令列表（用于缩进判断，feature #1）
	; 可直接添加未被默认支持的流程命令，确保其能被识别并缩进
	ListOfIFCommands = ,for,while,try,catch,finally,switch,class

	; 读取CommandNames.txt（存储AHK命令名），若文件不存在则报错退出
	CommandNamesFile = %PathSyntaxFiles%\CommandNames.txt
	IfNotExist %CommandNamesFile%
	{ MsgBox,,, Could not find the "CommandNames.txt" file.`nPlease edit the script:`n%A_ScriptFullPath%`nin Linenumber: %A_LineNumber%
		ExitApp
	}
	; 逐行读取CommandNames.txt
	Loop, Read , %CommandNamesFile%
	{ ; 移除行首尾的空格和制表符
		Line = %A_LoopReadLine%
		Line:=Trim(Line, " `t`r`n`v`f")

		; 获取行的第一个字符和前两个字符
		StringLeft,FirstChar, Line ,1
		StringLeft,FirstTwoChars, Line ,2

		; 若行为注释（以";"开头），跳过当前行
		If (FirstChar = ";")
			Continue
		; 若为指令（以"#"开头），添加到指令列表
		Else If (FirstChar = "#")
			ListOfDirectives=%ListOfDirectives%,%Line%
		; 若为If类命令（以"if"开头），提取第一个单词并添加到If命令列表
		Else If (FirstTwoChars = "if") {
			StringSplit, Array, Line, %A_Space% ; 按空格拆分行
			Line = %Array1% ; 取第一个单词（如IfInString）
			If (StrLen(Line) > 4) ; 仅保留4字符以上的命令
				ListOfIFCommands=%ListOfIFCommands%,%Line%
		}
	}
	; 移除列表开头的逗号，并转为小写（统一格式）
	StringTrimLeft,ListOfIFCommands,ListOfIFCommands,1
	StringTrimLeft,ListOfDirectives,ListOfDirectives,1

	; 去重排序If命令列表（按字母降序）
	Sort, ListOfIFCommands, U D,

	; 待读取的语法文件列表（CommandNames、Keywords等）
	FilesSyntax = CommandNames|Keywords|Keys|Variables

	; 遍历语法文件列表，读取每个文件的内容
	Loop, Parse, FilesSyntax, |
	{ String = ; 临时存储当前文件的语法单词
		SyntaxFile = %PathSyntaxFiles%\%A_LoopField%.txt ; 当前语法文件路径
		; 若语法文件不存在，报错退出
		IfNotExist %SyntaxFile%
		{ MsgBox,,, Could not find the syntax file "%A_LoopField%.txt".`nPlease edit the script:`n%A_ScriptFullPath%`nin Linenumber: %A_LineNumber%
			ExitApp
		}
		filename:=A_LoopField ; 当前语法文件名（用于后续判断）
		; 逐行读取当前语法文件
		Loop, Read , %SyntaxFile%
		{
			; 移除行首尾的空格和制表符
			Line = %A_LoopReadLine%
			Line:=Trim(Line, " `t`r`n`v`f")

			; 获取行的第一个字符（判断是否为注释或空行）
			StringLeft,FirstChar, Line ,1

			; 若行包含空格，跳过（语法单词不含空格）
			If InStr(Line," ")
				Continue
			; 若行为空，跳过
			Else If Line is Space
				Continue
			; 若为注释行，跳过
			Else If (FirstChar = ";")
				Continue
			; 若单词长度>4或为Variables列表（特殊处理，修复bug #6），添加到临时字符串
			Else If (StrLen(Line) > 4 or filename="Variables")
				String = %String%,%Line%
		}
		; 移除临时字符串开头的逗号
		StringTrimLeft,String,String,1
		; 将临时字符串赋值给与文件名同名的变量（如CommandNames = ...）
		%A_LoopField% := String
	}

	; 补充未包含在语法文件中的命令（确保这些命令能被大小写纠正）
	CommandNames = %CommandNames%,Gui,Run,Edit,Exit,goto,Send,Sort,Menu
									,Files,Reg,Parse,Read,Mouse,SendAndMouse,Permit,Screen,Relative
									,Pixel,Toggle,UseErrorLevel,AlwaysOn,AlwaysOff

	; 读取内置函数列表（从Functions.txt获取）
	BuildInFunctions =
	FunctionsFile = %PathSyntaxFiles%\Functions.txt
	; 若Functions.txt不存在，报错退出
	IfNotExist %SyntaxFile%
	{ MsgBox,,, Could not find the "Functions.txt" file.`nPlease edit the script:`n%A_ScriptFullPath%`nin Linenumber: %A_LineNumber%
		ExitApp
	}
	; 逐行读取Functions.txt
	Loop, Read , %FunctionsFile%
	{ ; 移除行首尾的空格和制表符
		Line = %A_LoopReadLine%

		; 获取行的第一个字符，拆分函数名与括号（如"ATan("拆分为"ATan"）
		StringLeft,FirstChar, Line ,1
		StringSplit, Line, Line, (
		Line1:=Trim(Line1, " `t`r`n`v`f")

		; 若行为空，跳过
		If Line is Space
			Continue
		; 若为注释行，跳过
		Else If (FirstChar = ";")
			Continue
		; 将函数名+括号（如"ATan("）添加到内置函数列表
		Else
			BuildInFunctions = %BuildInFunctions%,%Line1%(
	}
	; 暂不移除开头的逗号（后续纠正时处理）
Return

;#############   从INI文件读取配置数据   ####################################
ReadDataFromIni:
	; 读取INI文件中的各项设置（格式：IniRead, 变量名, INI路径, 节名, 键名, 默认值）
	IniRead, Extension, %IniFile%, Settings, Extension, _autoindent_%Version%.ahk ; 输出文件扩展名
	IniRead, Indentation, %IniFile%, Settings, Indentation, 1 ; 缩进方式（1=制表符，2=空格）
	IniRead, NumberSpaces, %IniFile%, Settings, NumberSpaces, 2 ; 空格缩进时的空格数量
	IniRead, NumberIndentCont, %IniFile%, Settings, NumberIndentCont, 1 ; 续行缩进的数量
	IniRead, IndentCont, %IniFile%, Settings, IndentCont, 1 ; 续行缩进方式（1=制表符，2=空格）
	IniRead, Style, %IniFile%, Settings, Style, 1 ; 缩进风格（1=Rajat，2=Toralf，3=BoBo）
	IniRead, CaseCorrectCommands, %IniFile%, Settings, CaseCorrectCommands, 1 ; 命令大小写纠正（1=开启）
	IniRead, CaseCorrectVariables, %IniFile%, Settings, CaseCorrectVariables, 1 ; 变量大小写纠正（1=开启）
	IniRead, CaseCorrectBuildInFunctions, %IniFile%, Settings, CaseCorrectBuildInFunctions, 1 ; 内置函数大小写纠正（1=开启）
	IniRead, CaseCorrectKeys, %IniFile%, Settings, CaseCorrectKeys, 1 ; 按键名大小写纠正（1=开启）
	IniRead, CaseCorrectKeywords, %IniFile%, Settings, CaseCorrectKeywords, 0		; 关键词大小写纠正（默认关闭，修复bug #2）
	IniRead, CaseCorrectDirectives, %IniFile%, Settings, CaseCorrectDirectives, 1 ; 指令大小写纠正（1=开启）
	IniRead, Statistic, %IniFile%, Settings, Statistic, 1 ; 统计功能（1=开启）
	IniRead, ChkSpecialTabIndent, %IniFile%, Settings, ChkSpecialTabIndent, 1 ; GuiTab特殊缩进（1=开启）
	IniRead, KeepBlockCommentIndent, %IniFile%, Settings, KeepBlockCommentIndent, 0 ; 保留块注释缩进（1=开启）
	IniRead, AHKPath, %IniFile%, Settings, AHKPath, %A_Space% ; AHK路径（已被固定为脚本目录，此处仅读取）
	IniRead, OwnHotKey, %IniFile%, Settings, OwnHotKey, F2 ; 自定义缩进热键（默认F2）
Return

;#############   自定义热键变更处理   ####################################
OwnHotKey:
	; 禁用旧热键
	Hotkey, IfWinNotActive, %GuiUniqueID%
	Hotkey, %OldHtk%, IndentHighlightedText, Off
	; 若新热键为空，恢复旧热键并更新Gui
	If OwnHotKey is Space
	{
		Hotkey, %OldHtk%, IndentHighlightedText
		GuiControl, , OwnHotKey, %OldHtk%
	}Else{
		; 设置新热键并更新旧热键记录
		Hotkey, %OwnHotKey%, IndentHighlightedText
		OldHtk = %OwnHotKey%
	}
	Hotkey, IfWinNotActive,
Return

;#############   构建Gui界面   #############################
BuildGui:
	; 初始化日志文本（显示操作提示）
	LogText = Drop your files for indentation on this Gui.`nOr highlight AHK syntax in script and press %OwnHotKey%.`n`n

	; 设置Gui属性（工具窗口、始终置顶）
	Gui, +ToolWindow +AlwaysOnTop
	; 添加Gui控件（热键设置）
	Gui, Add, Text, xm Section ,Hotkey
	Gui, Add, Hotkey, ys-3 r1 w165 vOwnHotKey gOwnHotKey, %OwnHotKey%

	; 添加文件扩展名输入框
	Gui, Add, Text, xm Section ,Extension for files
	Gui, Add, Edit, ys-3 r1 w117 vExtension, %Extension%

	; 添加缩进设置分组框
	Gui, Add, GroupBox, xm w210 r6.3,Indentation
	Gui, Add, Text, xp+8 yp+15 Section,Type:
	Gui, Add, Radio, ys vIndentation,1xTab or
	Gui, Add, Radio, ys Checked,Spaces
	Gui, Add, Edit, ys-3 r1 Limit1 Number w15 vNumberSpaces, %NumberSpaces%
	Gui, Add, Text, xs Section,Style:
	Gui, Add, Radio, x+8 ys vStyle,Rajat
	Gui, Add, Radio, x+8 ys Checked,Toralf
	Gui, Add, Radio, x+8 ys ,BoBo
	Gui, Add, Text, xs Section,Indentation of Method1 continuation Lines:
	Gui, Add, Edit, xs ys+15 Section r1 Limit2 Number w20 vNumberIndentCont, %NumberIndentCont%
	Gui, Add, Radio, ys+4 vIndentCont ,Tabs or
	Gui, Add, Radio, ys+4 Checked,Spaces
	Gui, Add, Checkbox, xs vKeepBlockCommentIndent Checked%KeepBlockCommentIndent%, Preserve indent. in Block comments
	Gui, Add, Checkbox, xs vChkSpecialTabIndent Checked%ChkSpecialTabIndent%, Special "Gui,Tab" indent

	; 添加大小写纠正设置分组框
	Gui, Add, GroupBox, xm w210 r3,Case-Correction for
	Gui, Add, Checkbox, xp+8 yp+18 Section vCaseCorrectCommands Checked%CaseCorrectCommands%,Commands
	Gui, Add, Checkbox, vCaseCorrectVariables Checked%CaseCorrectVariables%,Variables
	Gui, Add, Checkbox, vCaseCorrectBuildInFunctions Checked%CaseCorrectBuildInFunctions%,Build in functions
	Gui, Add, Checkbox, ys vCaseCorrectKeys Checked%CaseCorrectKeys%,Keys
	Gui, Add, Checkbox, vCaseCorrectKeywords Checked%CaseCorrectKeywords% Disabled,Keywords ; 禁用关键词纠正（防止DllCall错误）
	Gui, Add, Checkbox, vCaseCorrectDirectives Checked%CaseCorrectDirectives%,Directives

	; 添加统计功能复选框和日志显示框
	Gui, Add, Text, xm Section, Information
	Gui, Add, Checkbox, ys vStatistic Checked%Statistic%, Statistic
	Gui, Add, Edit, xm r10 w210 vlog ReadOnly, %LogText%

	; 根据INI配置设置Radio按钮状态（缩进方式、风格、续行缩进方式）
	If (Indentation = 1)
		GuiControl,,1xTab or,1
	If (Style = 1)
		GuiControl,,Rajat,1
	Else If (Style = 3)
		GuiControl,,BoBo,1
	If (IndentCont = 1)
		GuiControl,, IndentCont, 1

	; 读取上一次Gui位置并显示（默认居中）
	IniRead, Pos_Gui, %IniFile%, General, Pos_Gui, CEnter
	Gui, Show, %Pos_Gui% %param_Hidden% ,%ScriptName%
	; 获取Gui的唯一ID（用于后续热键过滤）
	Gui, +LastFound
	GuiUniqueID := "ahk_id " WinExist()

	; 获取日志控件的ClassNN（用于后续滚动日志到末尾）
	GuiControl, Focus, Log
	ControlGetFocus, ClassLog, %GuiUniqueID%
	GuiControl, Focus, Extension
Return

;#############   托盘图标切换Gui显示/隐藏   ###################
ShowHideGui:
	; 若当前Gui隐藏，则显示；否则隐藏
	If param_Hidden {
		Gui, Show
		param_Hidden =
	}Else{
		param_Hidden = Hide
		Gui, Show, %param_Hidden%
	}
Return

;#############   条件判断函数（iif）：根据表达式返回a或b   #######
iif(exp,a,b=""){
	If exp
		Return a
	Return b
}

;#############   热键触发：缩进编辑器中选中的文本   ######################
IndentHighlightedText:
	; 记录开始时间（用于统计处理耗时）
	StartTime = %A_TickCount%

	; 保存并清空剪贴板（避免原有内容干扰）
	ClipSaved := ClipboardAll
	Clipboard =
	Sleep, 50           ; 等待剪贴板清空（修复bug #5：兼容ClipJump等工具）

	; 将选中内容复制到剪贴板
	Send, ^c

	; 获取当前活动窗口的唯一ID
	WinUniqueID := WinExist("A")

	; 若剪贴板为空（无选中内容），全选并复制
	If Clipboard is Space
	{ ; 全选并复制
		Send, ^a^c
	}

	; 移除剪贴板中的回车符（统一换行格式为`n）
	StringReplace, ClipboardString, Clipboard, `r`n, `n, All

	; 恢复原始剪贴板内容并释放内存
	Clipboard := ClipSaved
	ClipSaved =

	; 若仍无内容可处理，弹出提示
	If ClipboardString is Space
		MsgBox, 0 , %ScriptName%,
	(LTrim
		Couldn't get anything to indent.
		Please try again.
	), 1
	Else {
		; 提交Gui设置（获取当前配置）
		Gui, Submit, NoHide

		; 计算待处理的行数（用于进度条）
		StringReplace, x, ClipboardString, `n, `n, All UseErrorLevel
		NumberOfLines = %ErrorLevel%
		; 显示进度条（阻止输入干扰）
		Progress, R0-%NumberOfLines% FM10 WM8000 FS8 WS400, `n, Please wait`, auto-syntax-tidy is Running, %ScriptName%
		BlockInput, On

		; 设置大小写纠正的语法列表（按优先级排序）
		Gosub, SetCaseCorrectionSyntax

		; 根据配置创建缩进字符（制表符或空格）
		Gosub, CreateIndentSize

		; 重置所有临时变量（准备处理文本）
		Gosub, SetStartValues

		; 逐行解析剪贴板中的文本并执行缩进
		Loop, Parse, ClipboardString, `n
		{ ; 保留原始行（含缩进）
			AutoTrim, Off
			Original_Line = %A_LoopField%
			AutoTrim, On

			; 执行缩进逻辑
			Gosub, DoSyntaxIndentation

			; 每10行更新一次进度条
			If (Mod(A_Index, 10)=0)
				Progress, %A_Index%, Line: %A_Index% of %NumberOfLines%
		}

		; 纠正子程序和函数调用的大小写（与定义处同步）
		CaseCorrectSubsAndFuncNames()

		; 移除最后一个换行符（避免多余空行）
		StringTrimRight,String,String,1

		; 保存并清空剪贴板
		ClipSaved := ClipboardAll
		Clipboard =
		Sleep, 50           ; 等待剪贴板清空（修复bug #5）

		; 将处理后的文本写入剪贴板
		Clipboard = %String%

		; 关闭进度条并激活原窗口
		Progress, Off
		WinActivate, ahk_id %WinUniqueID%

		; 粘贴处理后的文本并将光标移至开头
		Send, ^v{HOME}
		; 恢复原始剪贴板内容
		Clipboard := ClipSaved
		ClipSaved =

		; 启用输入（解除BlockInput）
		BlockInput, Off

		; 记录日志并滚动到末尾
		LogText = %LogText%Indentation done for text in editor.`n
		If Statistic
			Gosub, AddStatisticToLog
		Else
			LogText = %LogText%`n
		GuiControl, ,Log , %LogText%
		ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
	}
Return

;#############   设置大小写纠正的语法列表（按优先级排序）   ##############################
SetCaseCorrectionSyntax:
	; 大小写纠正优先级（从低到高）：Keywords < Keys < Variables < CommandNames < ListOfDirectives
	; 低级与高级重复时，高级覆盖低级（如Keys的"click"被CommandNames的"Click"覆盖，feature #4）
	CaseCorrectionSyntax:=""
	If CaseCorrectKeywords
		CaseCorrectionSyntax.="," Keywords
	If CaseCorrectKeys
		CaseCorrectionSyntax.="," Keys
	If CaseCorrectVariables
		CaseCorrectionSyntax.="," Variables
	If CaseCorrectCommands
		CaseCorrectionSyntax.="," CommandNames
	If CaseCorrectDirectives
		CaseCorrectionSyntax.="," ListOfDirectives
	; 移除开头的逗号
	StringTrimLeft, CaseCorrectionSyntax, CaseCorrectionSyntax, 1
Return

;#############   根据配置创建缩进字符（制表符或空格）   ###############
CreateIndentSize:
	; 清空缩进字符变量
	IndentSize =
	IndentContLine =

	; 关闭自动修剪（确保空格/制表符被完整保留）
	AutoTrim, Off

	; 根据缩进方式创建基础缩进字符（1=制表符，2=空格）
	If Indentation = 1
		IndentSize = %A_Tab%
	Else
		Loop, %NumberSpaces%
			IndentSize = %IndentSize%%A_Space%

	; 根据续行缩进配置创建续行缩进字符
	If IndentCont = 1
		Loop, %NumberIndentCont%
			IndentContLine = %IndentContLine%%A_Tab%
	Else
		Loop, %NumberIndentCont%
			IndentContLine = %IndentContLine%%A_Space%

	; 恢复自动修剪（默认行为）
	AutoTrim, On
Return

;#############   重置所有临时变量（处理文本前初始化）   #####################################
SetStartValues:
	String =                 ; 存储处理后的文本（带缩进）
	Indent =                 ; 当前行的缩进字符（如"  "或"	"）
	IndentIndex = 0          ;缩进索引（对应IndentIncrement和IndentCommand数组）
	InBlockComment := False  ; 是否处于块注释中（/*...*/）
	InsideContinuation := False ; 是否处于续行块中（如括号内多行）
	InsideTab = 0            ; GuiTab缩进相关标记
	EmptyLineCount = 0       ; 空行计数（统计用）
	TotalLineCount = 0       ; 总行数计数（统计用）
	CommentLineCount = 0     ; 注释行计数（统计用）
	; 若启用内置函数大小写纠正，初始化函数列表（含内置函数）
	If CaseCorrectBuildInFunctions
		CaseCorrectFuncList = %BuildInFunctions%
	Else
		CaseCorrectFuncList =                     ; 脚本自定义函数列表
	CaseCorrectSubsList=     ; 脚本自定义子程序列表
	; 初始化缩进数组（最多支持11层缩进）
	Loop, 11{
		IndentIncrement%A_Index% =
		IndentCommand%A_Index% =
	}
Return

;#############   缩进所有拖放的文件   ###################################
GuiDropFiles:
	; 记录总处理开始时间（统计所有文件耗时）
	OverAllStartTime = %A_TickCount%

	; 提交Gui设置（获取当前配置）
	Gui, Submit,NoHide

	; 设置大小写纠正的语法列表
	Gosub, SetCaseCorrectionSyntax

	; 创建缩进字符（制表符/空格）
	Gosub, CreateIndentSize

	; 初始化总统计变量（所有文件合计）
	OverAllCodeLineCount = 0
	OverAllTotalLineCount = 0
	OverAllCommentLineCount = 0
	OverAllCommentLineCount = 0

	; 遍历所有拖放的文件，逐行处理并缩进
	Loop, Parse, A_GuiControlEvent, `n
	{ ; 记录当前文件处理开始时间
		StartTime = %A_TickCount%

		; 当前待处理文件路径
		FileToautoIndent = %A_LoopField%

		; 重置临时变量（处理新文件前初始化）
		Gosub, SetStartValues

		; 逐行读取文件并执行缩进
		Loop, Read, %FileToautoIndent%
		{ ; 保留原始行（含原有缩进）
			AutoTrim, Off
			Original_Line = %A_LoopReadLine%
			AutoTrim, On

			; 执行缩进逻辑
			Gosub, DoSyntaxIndentation
		}

		; 纠正子程序和函数调用的大小写
		CaseCorrectSubsAndFuncNames()

		; 将处理后的内容写入新文件（若未指定扩展名则覆盖原文件）
		FileDelete, %FileToautoIndent%%Extension%
		FileAppend, %String%,%FileToautoIndent%%Extension%

		; 记录当前文件处理日志
		LogText = %LogText%Indentation done for: %FileToautoIndent%`n
		If Statistic
			Gosub, AddStatisticToLog
		Else
			LogText = %LogText%`n
		GuiControl, ,Log , %LogText%
		ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
	}
	; 若启用统计功能，输出所有文件的合计统计
	If Statistic {
		LogText = %LogText%=====Statistics:=======`n
		LogText = %LogText%=====over all files====`n
		LogText = %LogText%Lines with code: %A_Tab%%A_Tab%%OverAllCodeLineCount%`n
		LogText = %LogText%Lines with comments: %A_Tab%%OverAllCommentLineCount%`n
		LogText = %LogText%Empty Lines: %A_Tab%%A_Tab%%OverAllEmptyLineCount%`n
		LogText = %LogText%Total Number of Lines: %A_Tab%%OverAllTotalLineCount%`n
		; 计算总耗时（毫秒转秒）
		OverAllTimeNeeded := (A_TickCount - OverAllStartTime) / 1000
		LogText = %LogText%Total Process time: %A_Tab%%OverAllTimeNeeded%[s]`n`n
		GuiControl, ,Log , %LogText%
		ControlSend, %ClassLog%, ^{End}, %GuiUniqueID%
	}
Return

;#############   向日志添加统计信息   ######################################
AddStatisticToLog:
	; 计算代码行数（总行数 - 注释行数 - 空行数）
	CodeLineCount := TotalLineCount - CommentLineCount - EmptyLineCount

	; 累加到总统计
	OverAllCodeLineCount    += CodeLineCount
	OverAllTotalLineCount   += TotalLineCount
	OverAllCommentLineCount += CommentLineCount
	OverAllEmptyLineCount   += EmptyLineCount

	; 拼接统计日志（含当前文件的行数、耗时）
	LogText = %LogText%=====Statistics:=====`n
	LogText = %LogText%Lines with code: %A_Tab%%A_Tab%%CodeLineCount%`n
	LogText = %LogText%Lines with comments: %A_Tab%%CommentLineCount%`n
	LogText = %LogText%Empty Lines: %A_Tab%%A_Tab%%EmptyLineCount%`n
	LogText = %LogText%Total Number of Lines: %A_Tab%%TotalLineCount%`n
	; 计算当前文件处理耗时（毫秒转秒）
	TimeNeeded := (A_TickCount - StartTime) / 1000
	LogText = %LogText%Process time: %A_Tab%%TimeNeeded%[s]`n`n
Return

;#############   处理命令行指定的文件（/in参数）   ##############################
IndentFile:
	; 设置大小写纠正的语法列表
	Gosub, SetCaseCorrectionSyntax

	; 创建缩进字符（制表符/空格）
	Gosub, CreateIndentSize

	; 当前待处理文件路径（命令行/in参数指定）
	FileToautoIndent = %param_in%

	; 重置临时变量
	Gosub, SetStartValues

	; 逐行读取文件并执行缩进
	Loop, Read, %FileToautoIndent%
	{ ; 保留原始行（含原有缩进）
		AutoTrim, Off
		Original_Line = %A_LoopReadLine%
		AutoTrim, On

		; 执行缩进逻辑
		Gosub, DoSyntaxIndentation
	}

	; 纠正子程序和函数调用的大小写
	CaseCorrectSubsAndFuncNames()

	; 删除原文件并写入处理后的内容（覆盖原文件）
	FileDelete, %FileToautoIndent%
	FileAppend, %String%, %FileToautoIndent%

	; 向日志文件写入处理信息
	LogText = Indentation done for: %FileToautoIndent%`n
	If Statistic
		Gosub, AddStatisticToLog
	FileAppend , %LogText%, %param_log%
Return

;#############   根据缩进索引设置下一行的缩进   ##
SetIndentForNextLoop:
	; 清空当前缩进字符
	Indent =
	; 防止缩进索引为负（异常处理）
	If IndentIndex < 0
		IndentIndex = 0

	; 关闭自动修剪（确保缩进字符完整）
	AutoTrim, Off

	; 根据缩进索引生成缩进字符（叠加每层缩进）
	Loop, %IndentIndex% {
		Increments := IndentIncrement%A_Index%
		Loop, %Increments%
			Indent = %Indent%%IndentSize%
	}

	; 恢复自动修剪（默认行为）
	AutoTrim, On
Return

;#############   从行中移除注释（保留代码部分）   ###################################
StripCommentsFromLine(Line) {
	StartPos = 1
	; 遍历行中的分号（从第二个分号开始判断，避免误删代码中的分号）
	Loop {
		; 查找下一个分号的位置（从当前位置+1开始）
		StartPos := InStr(Line,";","",StartPos + 1)
		If (StartPos > 1) {
			; 判断分号是否为注释（排除转义分号、表达式内分号等情况）
			StringMid,CharBeforeSemiColon, Line, StartPos - 1 , 1
			; 情况1：分号被转义（`;），跳过
			If (CharBeforeSemiColon = "``")
				Continue
			; 情况2：分号在赋值表达式（:=）右侧且被引号包裹（非注释）
			Else If ( 0 < InStr(Line,":=") AND InStr(Line,":=") < StartPos
											AND 0 < InStr(Line,"""") AND InStr(Line,"""") < StartPos
											AND 0 < InStr(Line,"""","",StartPos) )
				Continue
			; 情况3：分号在括号表达式内且被引号包裹（非注释）
			Else If ( 0 < InStr(Line,"(") AND InStr(Line,"(") < StartPos
											AND InStr(Line,")","",StartPos) > StartPos
											AND 0 < InStr(Line,"""") AND InStr(Line,"""") < StartPos
											AND 0 < InStr(Line,"""","",StartPos) )
				Continue
			; 情况4：分号为注释分隔符，截断行并返回代码部分
			Else {
				StringLeft, Line, Line, StartPos - 1
				Line = %Line%
				Return Line
			}
		} Else
			; 无分号，直接返回整行（无注释）
			Return Line
	}
}

;#############   存储缩进记录的函数（MemorizeIndent）   ########
MemorizeIndent(Command,Increment,Index=0){
	global ; 引用全局变量
	; 根据Index调整缩进索引（+1=增加层，-1=重置到指定层）
	If (Index > 0)
		IndentIndex += %Index%
	Else If (Index < 0)
		IndentIndex := Abs(Index)
	; 记录当前层的命令类型和缩进增量
	IndentCommand%IndentIndex% = %Command%
	IndentIncrement%IndentIndex% = %Increment%
}

;#############   核心逻辑：为每行代码执行语法缩进   #########
DoSyntaxIndentation:
	; 总行数+1（统计用）
	TotalLineCount ++

	;##################################
	; 第一步：判断行是否为空行
	;##################################
	; 保留原始行（含原有缩进）
	Line = %Original_Line%

	; 若行为空（仅空格/制表符），直接添加空行并计数
	If Line is Space {
		String = %String%`n
		EmptyLineCount ++
		Gosub, FinishThisLine
		Return ; 处理下一行
	}

	;##################################
	; 第二步：判断行的首字符（块注释、热字符串等）
	;##################################
	; 获取行的首字符和前两个字符
	StringLeft,  FirstChar    , Line, 1
	StringLeft,  FirstTwoChars, Line, 2

	FinishThisLine := False ; 是否直接结束当前行处理的标记

	; 关闭自动修剪（保留行内空格/制表符）
	AutoTrim, Off

	; 情况1：行是块注释结束（*/）
	If (FirstTwoChars = "*/") {
		String = %String%%Line%`n
		InBlockComment := False ; 退出块注释状态
		CommentLineCount ++ ; 注释行计数+1
		FinishThisLine := True
	}

	; 情况2：行处于块注释中（/*...*/内）
	Else If InBlockComment {
		; 根据配置决定是否保留块注释的原有缩进
		If KeepBlockCommentIndent
			String = %String%%Original_Line%`n
		Else
			String = %String%%Line%`n
		CommentLineCount ++
		FinishThisLine := True
	}

	; 情况3：行是块注释开始（/*）
	Else If (FirstTwoChars = "/*") {
		String = %String%%Line%`n
		InBlockComment := True ; 进入块注释状态
		CommentLineCount ++
		FinishThisLine := True
	}

	; 情况4：行是热字符串（以":"开头）
	Else If (FirstChar = ":") {
		String = %String%%Line%`n
		MemorizeIndent("Sub",1,-1) ; 记录子程序缩进（重置到当前层）
		FinishThisLine := True
	}

	; 情况5：行是单行注释（以";"开头）
	Else If (FirstChar = ";") {
		String = %String%%Indent%%Line%`n ; 按当前缩进添加注释
		CommentLineCount ++
		FinishThisLine := True
	}

	; 若上述情况已处理完当前行，执行收尾并处理下一行
	If FinishThisLine {
		Gosub, FinishThisLine
		Return
	}

	; 恢复自动修剪（默认行为）
	AutoTrim, On

	;##################################
	; 第三步：解析行的代码部分（移除注释）
	;##################################
	; 获取行的代码部分（不含注释）
	StripedLine := StripCommentsFromLine(Line)

	; 获取代码部分的最后一个字符（判断是否为OTB块开头，如"If {"）
	StringRight, LastChar     , StripedLine, 1

	; 拆分代码部分为单词（获取前三个单词，用于判断命令类型）
	Loop, 3
		CommandLine%A_Index% =
	; 替换制表符、逗号、括号为空格（统一分隔符）
	StringReplace, CommandLine, StripedLine, %A_Tab%, %A_Space%,All
	StringReplace, CommandLine, CommandLine, `, , %A_Space%,All
	StringReplace, CommandLine, CommandLine, {, %A_Space%,All
	StringReplace, CommandLine, CommandLine, }, %A_Space%,All
	StringReplace, CommandLine, CommandLine, %A_Space%if(, %A_Space%if%A_Space%,All
	StringReplace, CommandLine, CommandLine, ), %A_Space%,All
	; 合并多个空格为单个空格
	StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%%A_Space%%A_Space%, %A_Space%,All
	StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%%A_Space%, %A_Space%,All
	StringReplace, CommandLine, CommandLine, %A_Space%%A_Space%, %A_Space%,All
	CommandLine = %CommandLine% ; 移除首尾空格
	StringSplit, CommandLine, CommandLine, %A_Space% ; 按空格拆分为单词数组
	FirstWord  = %CommandLine1% ; 第一个单词（通常是命令）
	SecondWord = %CommandLine2% ; 第二个单词
	ThirdWord  = %CommandLine3% ; 第三个单词

	; 获取第一个单词的最后一个字符（判断是否为子程序定义，如"Sub:"）
	StringRight, FirstWordLastChar,  FirstWord,  1

	;##################################
	; 第四步：纠正函数定义判断（避免误判非函数行）
	;##################################
	; 若当前无缩进、首字符不是"{"，但之前判断为函数，需重新验证
	If ( FirstChar <> "{" AND IndentIndex = 1 AND   FunctionName <> "") {
		FunctionName = ; 清空函数名（非函数定义）
		IndentIndex = 0 ; 重置缩进索引
		Gosub, SetIndentForNextLoop
	}

	; 假设当前行不是函数定义
	FirstWordIsFunction := False
	; 若无缩进且第一个单词含"("，判断是否为函数定义（如"Func()"）
	If ( IndentIndex = 0 And InStr(FirstWord,"(") > 0 )
		FirstWordIsFunction := ExtractFunctionName(FirstWord,InStr(FirstWord,"("),FunctionName)

	;##################################
	; 第五步：GuiTab特殊缩进判断（根据配置）
	;##################################
	LineIsTabSpecialIndentStart := False ; 是否为"Gui, Add, Tab"
	LineIsTabSpecialIndent      := False ; 是否为"Gui, Tab, 名称"
	LineIsTabSpecialIndentEnd   := False ; 是否为"Gui, Tab"（无名称）
	If (ChkSpecialTabIndent AND FirstWord = "Gui") {
		; 情况1：Gui添加Tab控件（如"Gui, Add, Tab"）
		If (InStr(SecondWord,"add") And ThirdWord = "tab")
			LineIsTabSpecialIndentStart := True
		; 情况2：Gui切换Tab（含名称，如"Gui, Tab, MyTab"）
		Else If (InStr(SecondWord,"tab")) {
			If ThirdWord is Space
				LineIsTabSpecialIndentEnd := True ; 情况3：无名称（结束Tab缩进）
			Else
				LineIsTabSpecialIndent := True
		}
	}

	; 关闭自动修剪（保留缩进字符）
	AutoTrim, Off

	;###### 第六步：根据命令类型调整缩进 ##########

	; 情况1：行是指令（如#IfWinActive）
	If FirstWord in %ListOfDirectives% {
		; 执行大小写纠正（全字匹配，修复bug #7）
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)
		String = %String%%Line%`n ; 指令无缩进
	}
	; 情况2：行是热键（含"::"且首字符为修饰符，如"^a::"）
	Else If InStr("#!^+<>*~$", FirstChar) AND InStr(FirstWord,"::") {
		String = %String%%Line%`n
		MemorizeIndent("Sub",1,-1) ; 记录子程序缩进
	}
	; 情况3：行是隐式续行（以","、"||"、"&&"、"and"、"or"开头）
	Else If (FirstChar = "," OR FirstTwoChars = "||" OR FirstTwoChars = "&&"
									OR FirstWord = "and" OR FirstWord = "or" ) {
		String = %String%%Indent%%IndentContLine%%Line%`n ; 按续行缩进
	}
	; 情况4：行是续行块结束（")"且处于续行中）
	Else If (FirstChar = ")" and InsideContinuation) {
		Gosub, SetIndentOfLastBracket ; 调整到最后一个括号的缩进
		String := String . Indent . iif(Style=1,"",IndentSize) . Line . "`n"
		InsideContinuation := False ; 退出续行状态
	}
	; 情况5：行处于续行块中（如括号内多行）
	Else If InsideContinuation {
		; 根据配置决定是否调整续行缩进
		If AdjustContinuation
			String = %String%%Indent%%Line%`n
		Else
			String = %String%%Original_Line%`n ; 保留原有缩进
	}
	; 情况6：行是续行块开始（"("）
	Else If (FirstChar = "(") {
		String := String . Indent . iif(Style>1,IndentSize) . Line . "`n"
		MemorizeIndent("(",iif(Style=2,2,1),+1) ; 记录括号缩进
		AdjustContinuation := False
		; 若含"LTrim"且不含"RTrim0"，启用续行缩进调整
		If ( InStr(StripedLine, "LTrim") > 0 AND InStr(StripedLine, "RTrim0") = 0)
			AdjustContinuation := True
		InsideContinuation := True ; 进入续行状态
	}
	; 情况7：行是Gui添加Tab控件（"Gui, Add, Tab"）
	Else If LineIsTabSpecialIndentStart {
		String = %String%%Indent%%Line%`n
		MemorizeIndent("AddTab",1,+1) ; 增加Tab缩进
	}
	; 情况8：行是Gui切换到指定Tab（"Gui, Tab, 名称"）
	Else If LineIsTabSpecialIndent {
		Gosub, SetIndentOfLastAddTaborBracket ; 调整到最后一个Tab或括号的缩进
		String = %String%%Indent%%IndentSize%%Line%`n ; 增加一层缩进
		MemorizeIndent("Tab",1,+2)
	}
	; 情况9：行是Gui结束Tab切换（"Gui, Tab"）
	Else If LineIsTabSpecialIndentEnd {
		Gosub, SetIndentOfLastAddTaborBracket
		String = %String%%Indent%%Line%`n
	}
	; 情况10：行是子程序/热键定义（以":"结尾，如"Sub:"）
	Else If (FirstWordLastChar = ":") {
		; 若不是热字符串（不含"::"），则为子程序定义
		If (InStr(FirstWord,"::") = 0) {
			StringTrimRight, SubroutineName, Line, 1 ; 移除末尾的":"
			; 将子程序名添加到列表（用于后续大小写同步）
			If SubroutineName not in %CaseCorrectSubsList%
				CaseCorrectSubsList = %CaseCorrectSubsList%,%SubroutineName%
		}
		String = %String%%Line%`n
		MemorizeIndent("Sub",1,-1) ; 记录子程序缩进
	}
	; 情况11：行是代码块结束（"}"）
	Else If (FirstChar = "}") {
		; 特殊情况："} else ..."（OTB格式，如"}else{"）
		If (FirstWord = "else"){
			; 纠正else大小写（强制小写，feature #2）
			StringReplace, Line, Line, else, else
			; 纠正其他语法单词大小写
			Loop, Parse, CaseCorrectionSyntax, `,
				Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

			Gosub, SetIndentOfLastCurledBracket ; 调整到最后一个花括号的缩进
			IndentIndex --
			Gosub, SetIndentOfLastIfOrOneLineIf ; 调整到最后一个If或单行If的缩进

			; else后可能紧跟If/Loop等，需记录新缩进
			If SecondWord in %ListOfIFCommands% { ; 旧If语句（如"IfInString"）
				StringReplace, Line, Line, if, if ; 强制if小写
				; 检查是否为单行If（含第三个逗号）
				StringReplace, ParsedCommand, StripedLine, ```, ,,All
				StringGetPos, ParsedCommand, ParsedCommand , `, ,L3
				If ErrorLevel ; 非单行If，增加缩进
					MemorizeIndent("If",iif(Style=1,0,1),+1)
			}Else If (SecondWord = "if") { ; 普通If语句
				StringReplace, Line, Line, if, if
				MemorizeIndent("If",iif(Style=1,0,1),+1)
				If (LastChar = "{") ; OTB格式（如"if(){"）
					MemorizeIndent("{",iif(Style=3,0,1),+1)
			}Else If (SecondWord = "loop"){ ; else后接Loop
				StringReplace, Line, Line, loop, loop ; 强制loop小写
				MemorizeIndent("Loop",iif(Style=1,0,1),+1)
				If (LastChar = "{") ; OTB格式
					MemorizeIndent("{",iif(Style=3,0,1),+1)
			}Else If SecondWord is Space { ; 单纯的else
				MemorizeIndent("Else",iif(Style=1,0,1),+1)
				If (LastChar = "{") ; OTB格式
					MemorizeIndent("{",iif(Style=3,0,1),+1)
			}
			String = %String%%Indent%%Line%`n
		}Else { ; 普通代码块结束（不含else）
			Gosub, SetIndentOfLastCurledBracket
			String = %String%%Indent%%Line%`n
			IndentIndex -- ; 减少缩进层级
		}
	}
	; 情况12：行是代码块开始（"{"）
	Else If (FirstChar = "{") {
		; 若为函数实现（之前已识别函数名且无缩进）
		If ( IndentIndex = 1 AND  FunctionName <> "" )
			; 将函数名添加到列表（含括号，用于后续大小写同步）
			If FunctionName not in %CaseCorrectFuncList%
				CaseCorrectFuncList = %CaseCorrectFuncList%,%FunctionName%(
		FunctionName = ; 清空函数名

		; 记录花括号缩进
		IndentIndex ++
		IndentCommand%IndentIndex% = {
		IndentIncrement%IndentIndex% := iif(Style=3,0,1)

		; 花括号后可能紧跟Loop/If等命令（如"{ loop ..."）
		If (FirstWord = "loop"){ ; 花括号后接Loop
			StringReplace, Line, Line, loop, loop
			Loop, Parse, CaseCorrectionSyntax, `,
				Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)
			MemorizeIndent("Loop",iif(Style=1,0,1),+1)
			If (LastChar = "{") ; OTB格式
				MemorizeIndent("{",iif(Style=3,0,1),+1)
		}Else If FirstWord in %ListOfIFCommands% { ; 花括号后接旧If语句
			StringReplace, Line, Line, if, if
			Loop, Parse, CaseCorrectionSyntax, `,
				Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)
			MemorizeIndent("If",iif(Style=1,0,1),+1)
		}Else If (FirstWord = "if"){ ; 花括号后接普通If
			StringReplace, Line, Line, if, if
			Loop, Parse, CaseCorrectionSyntax, `,
				Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)
			MemorizeIndent("If",iif(Style=1,0,1),+1)
			If (LastChar = "{") ; OTB格式
				MemorizeIndent("{",iif(Style=3,0,1),+1)
		}
		String = %String%%Indent%%Line%`n
	}
	; 情况13：行是函数定义（如"Func() { ..."）
	Else If FirstWordIsFunction {
		String = %String%%Line%`n
		; 注释此行可使函数后的花括号不缩进（feature #3）
		; MemorizeIndent("Func",1,-1)

		; 若函数定义使用OTB格式（如"Func(){"）
		If (LastChar = "{") {
			; 添加函数名到列表（用于大小写同步）
			If FunctionName not in %CaseCorrectFuncList%
				CaseCorrectFuncList = %CaseCorrectFuncList%,%FunctionName%(
			FunctionName = ; 清空函数名

			MemorizeIndent("{",iif(Style=3,0,1),+1) ; 记录花括号缩进
		}
	}
	; 情况14：行是Loop语句
	Else If (FirstWord = "loop") {
		; 纠正loop大小写（强制小写，feature #2）
		StringReplace, Line, Line, loop, loop
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

		PrevCommand := IndentCommand%IndentIndex% ; 上一层命令类型
		; 若上一层是If，当前为If块内的单行Loop
		If (PrevCommand = "If"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineIf",iif(Style=2,2,1))
		}
		; 若上一层是Else，当前为Else块内的单行Loop
		Else If (PrevCommand = "Else"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineElse",iif(Style=2,2,1))
		}
		; 若上一层是Loop，当前为Loop块内的单行Loop
		Else If (PrevCommand = "Loop"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
		}
		; 其他情况（子程序、代码块等之后的Loop）
		Else {
			Gosub, SetIndentToLastSubBracketOrTab
			String = %String%%Indent%%Line%`n
		}
		; 记录Loop缩进
		MemorizeIndent("Loop",iif(Style=1,0,1),+1)
		If (LastChar = "{") ; OTB格式（如"loop {"）
			MemorizeIndent("{",iif(Style=3,0,1),+1)
	}
	; 情况15：行是旧If语句（如"IfInString"）
	Else If FirstWord in %ListOfIFCommands% {
		; 纠正if大小写（强制小写，feature #2）
		StringReplace, Line, Line, if, if
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

		PrevCommand := IndentCommand%IndentIndex%
		; 处理旧If语句（判断是否为单行If）
		ParsedCommand := StripCommentsFromLine(Line)
		StringReplace, ParsedCommand, ParsedCommand, ```, ,,All
		StringGetPos, ParsedCommand, ParsedCommand , `, ,L3 ; 查找第三个逗号
		If ( ErrorLevel = 0 ){ ; 含第三个逗号，为单行If
			If (PrevCommand = "If"){ ; If块内的单行命令
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineIf",0)
				MemorizeIndent("OneLineCommand",0,+1)
			}Else If (PrevCommand = "Else"){ ; Else块内的单行命令
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineElse",0)
				MemorizeIndent("OneLineCommand",0,+1)
			}Else If (PrevCommand = "Loop"){ ; Loop块内的单行命令
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineLoop",0)
				MemorizeIndent("OneLineCommand",0,+1)
			}Else { ; 普通单行If
				Gosub, SetIndentToLastSubBracketOrTab
				String = %String%%Indent%%Line%`n
			}
		}Else { ; 非单行If
			If (PrevCommand = "If"){ ; If块内的首行
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineIf",iif(Style=2,2,1))
			} Else If (PrevCommand = "Else"){ ; Else块内的首行
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineElse",iif(Style=2,2,1))
			} Else If (PrevCommand = "Loop"){ ; Loop块内的首行
				String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
				MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
			} Else { ; 其他情况
				Gosub, SetIndentToLastSubBracketOrTab
				String = %String%%Indent%%Line%`n
			}
			; 记录If缩进
			MemorizeIndent("If",iif(Style=1,0,1),+1)
		}
	}
	; 情况16：行是普通If语句（"if ..."）
	Else If (FirstWord = "if"){
		; 纠正if大小写（强制小写，feature #2）
		StringReplace, Line, Line, if, if
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

		PrevCommand := IndentCommand%IndentIndex%
		If (PrevCommand = "If"){ ; If块内的If
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineIf",iif(Style=2,2,1))
		} Else If (PrevCommand = "Else"){ ; Else块内的If
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineElse",iif(Style=2,2,1))
		} Else If (PrevCommand = "Loop"){ ; Loop块内的If
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineLoop",iif(Style=2,2,1))
		} Else { ; 其他情况
			Gosub, SetIndentToLastSubBracketOrTab
			String = %String%%Indent%%Line%`n
		}
		; 记录If缩进
		MemorizeIndent("If",iif(Style=1,0,1),+1)
		If (LastChar = "{") ; OTB格式（如"if(){"）
			MemorizeIndent("{",iif(Style=3,0,1),+1)
	}
	; 情况17：行是Else语句
	Else If (FirstWord = "else") {
		; 纠正else大小写（强制小写，feature #2）
		StringReplace, Line, Line, else, else
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

		PrevCommand := IndentCommand%IndentIndex%
		; 若上一层是单行命令或Else，调整缩进
		If PrevCommand in OneLineCommand,Else
			Gosub, SetIndentOfLastIfOrOneLineIf

		; Else后可能紧跟If/Loop等
		If SecondWord in %ListOfIFCommands% { ; 旧If语句
			StringReplace, Line, Line, if, if
			StringReplace, ParsedCommand, StripedLine, ```, ,,All
			StringGetPos, ParsedCommand, ParsedCommand , `, ,L3
			If ErrorLevel ; 非单行If
				MemorizeIndent("If",1,+1)
		}Else If (SecondWord = "if"){ ; 普通If
			StringReplace, Line, Line, if, if
			MemorizeIndent("If",iif(Style=1,0,1),+1)
			If (LastChar = "{") ; OTB格式
				MemorizeIndent("{",iif(Style=3,0,1),+1)
		}Else If (Secondword = "loop"){ ; Else后接Loop
			StringReplace, Line, Line, loop, loop
			MemorizeIndent("Loop",iif(Style=1,0,1),+1)
			If (LastChar = "{") ; OTB格式
				MemorizeIndent("{",iif(Style=3,0,1),+1)
		}Else If SecondWord is Space { ; 单纯的Else
			MemorizeIndent("Else",iif(Style=1,0,1),+1)
			If (LastChar = "{") ; OTB格式
				MemorizeIndent("{",iif(Style=3,0,1),+1)
		}
		String = %String%%Indent%%Line%`n
	}
	; 情况18：行是普通命令或Return
	Else {
		; 执行大小写纠正
		Loop, Parse, CaseCorrectionSyntax, `,
			Line := RegExReplace(Line, "i)\b" A_LoopField "\b", A_LoopField)

		PrevCommand := IndentCommand%IndentIndex%
		; If块内的单行命令
		If (PrevCommand = "If"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineIf",0)
			MemorizeIndent("OneLineCommand",0,+1)
		}
		; Else块内的单行命令
		Else If (PrevCommand = "Else"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineElse",0)
			MemorizeIndent("OneLineCommand",0,+1)
		}
		; Loop块内的单行命令
		Else If (PrevCommand = "Loop"){
			String := String . Indent . iif(Style<>3,IndentSize) . Line . "`n"
			MemorizeIndent("OneLineLoop",0)
			MemorizeIndent("OneLineCommand",0,+1)
		}
		; 函数调用后的命令（理论上不会触发）
		Else If (PrevCommand = "Func"){
			String = %String%%Line%`n
			IndentIndex = 0
		}
		; 普通命令
		Else {
			Gosub, SetIndentToLastSubBracketOrTab
			PrevCommand := IndentCommand%IndentIndex%

			; 若为子程序内的Return，无缩进
			If (FirstWord = "Return" AND PrevCommand = "Sub") {
				String = %String%%Line%`n
				IndentIndex = 0
			}Else
				String = %String%%Indent%%Line%`n
		}
	}

	; 完成当前行处理，准备下一行缩进
	Gosub, FinishThisLine
Return

;#############   当前行处理收尾（设置下一行缩进）   ####################################
FinishThisLine:
	; 恢复自动修剪（默认行为）
	AutoTrim, On

	; 调试模式：显示当前行的处理信息
	If DebugMode
		Gosub, ShowDebugStrings

	; 计算下一行的缩进
	Gosub, SetIndentForNextLoop
Return

;#############   调试模式：显示当前行的详细信息   ######################################
ShowDebugStrings:
	msgtext = line#: %TotalLineCount%`n
	msgtext = %msgtext%Style: %Style%`n
	msgtext = %msgtext%line: %Line%`n
	msgtext = %msgtext%stripped line: %CommandLine%`n
	msgtext = %msgtext%Indent: |%Indent%|`n
	msgtext = %msgtext%1stChar: >%FirstChar%<`n
	msgtext = %msgtext%1st Word: >%FirstWord%<`n
	msgtext = %msgtext%2nd Word: >%SecondWord%<`n
	msgtext = %msgtext%3rd Word: >%ThirdWord%<`n
	msgtext = %msgtext%1st WordLastChar: >%FirstWordLastChar%<`n
	msgtext = %msgtext%FunctionName: >%FunctionName%<`n`n
	msgtext = %msgtext%IndentIndex: %IndentIndex%`n
	msgtext = %msgtext%Indent1: %IndentIncrement1% - %IndentCommand1%`n
	msgtext = %msgtext%Indent2: %IndentIncrement2% - %IndentCommand2%`n
	msgtext = %msgtext%Indent3: %IndentIncrement3% - %IndentCommand3%`n
	msgtext = %msgtext%Indent4: %IndentIncrement4% - %IndentCommand4%`n
	msgtext = %msgtext%Indent5: %IndentIncrement5% - %IndentCommand5%`n
	msgtext = %msgtext%Indent6: %IndentIncrement6% - %IndentCommand6%`n
	msgtext = %msgtext%Indent7: %IndentIncrement7% - %IndentCommand7%`n
	msgtext = %msgtext%Indent8: %IndentIncrement8% - %IndentCommand8%`n
	msgtext = %msgtext%Indent9: %IndentIncrement9% - %IndentCommand9%`n
	msgtext = %msgtext%Indent10: %IndentIncrement10% - %IndentCommand10%`n
	msgtext = %msgtext%Indent11: %IndentIncrement11% - %IndentCommand11%`n
	MsgBox %msgtext%`n%String%
Return

;#############   调整缩进索引到最后一个If或单行If   ##############
SetIndentOfLastIfOrOneLineIf:
	; 反向遍历缩进记录
	Loop, %IndentIndex% {
		InverseIndex := IndentIndex - A_Index + 2
		; 找到最近的If或单行If
		If IndentCommand%InverseIndex% in If,OneLineIf
		{ IndentIndex := InverseIndex - 1
			Break
		}
	}
	; 更新缩进字符
	Gosub, SetIndentForNextLoop
Return

;#############   调整缩进索引到最后一个花括号   ##############
SetIndentOfLastCurledBracket:
	; 反向遍历缩进记录
	Loop, %IndentIndex% {
		InverseIndex := IndentIndex - A_Index + 1
		; 找到最近的花括号
		If (IndentCommand%InverseIndex% = "{") {
			IndentIndex := InverseIndex - 1
			Break
		}
	}
	; 更新缩进字符
	Gosub, SetIndentForNextLoop
Return

;#############   调整缩进索引到最后一个圆括号   #####################
SetIndentOfLastBracket:
	; 反向遍历缩进记录
	Loop, %IndentIndex% {
		InverseIndex := IndentIndex - A_Index + 1
		; 找到最近的圆括号
		If (IndentCommand%InverseIndex% = "(") {
			IndentIndex := InverseIndex - 1
			Break
		}
	}
	; 更新缩进字符
	Gosub, SetIndentForNextLoop
Return

;#############   调整缩进索引到最后一个AddTab或括号   ######################
SetIndentOfLastAddTaborBracket:
	; 反向遍历缩进记录
	Loop, %IndentIndex% {
		InverseIndex := IndentIndex - A_Index + 1
		; 找到最近的AddTab或花括号
		If IndentCommand%InverseIndex% in {,AddTab
		{ IndentIndex := InverseIndex - 1
			Break
		}
	}
	; 更新缩进字符
	Gosub, SetIndentForNextLoop
Return

;#############   调整缩进索引到最后一个子程序或括号   ###############
SetIndentToLastSubBracketOrTab:
	FoundItem:=False
	; 反向遍历缩进记录
	Loop, %IndentIndex% {
		InverseIndex := IndentIndex - A_Index + 1

		; 找到最近的子程序或花括号
		If IndentCommand%InverseIndex% in {,Sub
		{ IndentIndex := InverseIndex
			FoundItem:=True
			Break
		}Else If ChkSpecialTabIndent
			; 若启用GuiTab缩进，同时查找AddTab或Tab
			If IndentCommand%InverseIndex% in AddTab,Tab
			{ IndentIndex := InverseIndex
				FoundItem:=True
				Break
			}
	}
	; 未找到则重置为0
	If ! FoundItem
		IndentIndex = 0

	; 更新缩进字符
	Gosub, SetIndentForNextLoop
Return

;#############   提取函数名（判断是否为合法函数）   #####################################
ExtractFunctionName(FirstWord,BracketPosition, ByRef FunctionName)  {
	; 提取括号前的部分作为函数名（如"Func(" → "Func"）
	StringLeft, FunctionName, FirstWord, % BracketPosition - 1

	; 排除"If("（是条件判断而非函数）
	If (FunctionName = "If")
		FunctionName =

	; 验证函数名合法性（支持中文，修复bug #3）
	RegExMatch(FunctionName, "SP)(*UCP)^[[:blank:]]*\K[\w#@\$\?\[\]]+", FunctionName_Len)
	If (FunctionName_Len<>StrLen(FunctionName))
		FunctionName =

	; 返回函数名长度（非空则为合法函数）
	Return StrLen(FunctionName)
}

;#############   纠正子程序和函数调用的大小写（与定义同步）   ############
CaseCorrectSubsAndFuncNames() {
	global
	LenString := StrLen(String)

	; 移除列表开头的逗号
	StringTrimLeft, CaseCorrectFuncList, CaseCorrectFuncList, 1
	StringTrimLeft, CaseCorrectSubsList, CaseCorrectSubsList, 1

	; 纠正函数调用的大小写
	Loop, Parse, CaseCorrectFuncList, CSV
	{ FuncName := A_LoopField
		LenFuncName := StrLen(FuncName)

		; 遍历文本查找所有函数调用
		StartPos = 0
		Loop {
			StartPos := InStr(String,FuncName,0,StartPos + 1)
			If (StartPos > 0) {
				; 确保函数名前不是字母/数字（避免部分匹配）
				StringMid,PrevChar, String, StartPos - 1 , 1
				If PrevChar is not Alnum
					ReplaceName( String, FuncName, StartPos-1, LenString - StartPos + 1 - LenFuncName )
			} Else
				Break
		}
	}

	; 纠正子程序调用的大小写
	Loop, Parse, CaseCorrectSubsList, CSV
	{ SubName := A_LoopField
		LenSubName := StrLen(SubName)

		; 遍历文本查找所有子程序调用
		StartPos = 0
		Loop {
			StartPos := InStr(String,SubName,"",StartPos + 1)
			If (StartPos > 0) {
				; 获取子程序名前后的字符
				StringMid,PrevChar, String, StartPos - 1 , 1
				StringMid,NextChar, String, StartPos + LenSubName, 1

				; 确保子程序名后不是字母/数字（全字匹配）
				If NextChar is not Alnum
				{ ; 情况1：前一个字符是"g"（如"Gui, Add, Button, gSub"）
					If ( PrevChar = "g" ) {
						TestAndReplaceSubName( String, SubName, "Gui,", LenString, LenSubName, StartPos)
						TestAndReplaceSubName( String, SubName, "Gui ", LenString, LenSubName, StartPos)
					}
					; 情况2：前一个字符不是字母/数字（如"Gosub Sub"）
					Else If PrevChar is not Alnum
					{ TestAndReplaceSubName( String, SubName, "Gosub" , LenString, LenSubName, StartPos )
						TestAndReplaceSubName( String, SubName, "Menu"  , LenString, LenSubName, StartPos )
						TestAndReplaceSubName( String, SubName, "`:`:"  , LenString, LenSubName, StartPos ) ; 热字符串
						TestAndReplaceSubName( String, SubName, "Hotkey", LenString, LenSubName, StartPos )
					}
				}
			} Else
				Break
		}
	}
}

;#############   验证并替换子程序名（确保在同一行且含指定命令）   ############
TestAndReplaceSubName( ByRef string, Name, TestString, LenString, LenSubName, StartPos ) {
	; 查找指定命令（如"Gosub"）和换行符在当前行的位置
	StringGetPos, PosTestString, String, %TestString%, R , LenString - StartPos + 1
	StringGetPos, PosLineFeed  , String,     `n      , R , LenString - StartPos + 1

	; 若命令与子程序名在同一行，执行替换
	If ( PosLineFeed < PosTestString )
		ReplaceName( String, Name, StartPos - 1, LenString - StartPos + 1 - LenSubName )
}

;#############   替换文本中的名称（保持前后内容不变）   ############
ReplaceName( ByRef String, Name, PosLeft, PosRight ) {
	; 拆分文本为名称左侧和右侧部分
	StringLeft, StrLeft, String, PosLeft
	StringRight, StrRight, String, PosRight

	; 拼接左侧+正确名称+右侧
	String = %StrLeft%%Name%%StrRight%
}

;#############   Gui关闭时保存配置并退出   #####################################
GuiClose:
	; 显示Gui以获取当前位置
	Gui, Show
	WinGetPos, PosX, PosY, SizeW, SizeH, %ScriptName%
	; 提交当前设置
	Gui, Submit
	; 保存配置到INI文件
	IniWrite, x%PosX% y%PosY%, %IniFile%, General, Pos_Gui
	IniWrite, %Extension%, %IniFile%, Settings, Extension
	IniWrite, %Indentation%, %IniFile%, Settings, Indentation
	IniWrite, %NumberSpaces%, %IniFile%, Settings, NumberSpaces
	IniWrite, %NumberIndentCont%, %IniFile%, Settings, NumberIndentCont
	IniWrite, %IndentCont%, %IniFile%, Settings, IndentCont
	IniWrite, %Style%, %IniFile%, Settings, Style
	IniWrite, %CaseCorrectCommands%, %IniFile%, Settings, CaseCorrectCommands
	IniWrite, %CaseCorrectVariables%, %IniFile%, Settings, CaseCorrectVariables
	IniWrite, %CaseCorrectBuildInFunctions%, %IniFile%, Settings, CaseCorrectBuildInFunctions
	IniWrite, %CaseCorrectKeys%, %IniFile%, Settings, CaseCorrectKeys
	IniWrite, %CaseCorrectKeywords%, %IniFile%, Settings, CaseCorrectKeywords
	IniWrite, %CaseCorrectDirectives%, %IniFile%, Settings, CaseCorrectDirectives
	IniWrite, %Statistic%, %IniFile%, Settings, Statistic
	IniWrite, %ChkSpecialTabIndent%, %IniFile%, Settings, ChkSpecialTabIndent
	IniWrite, %KeepBlockCommentIndent%, %IniFile%, Settings, KeepBlockCommentIndent
	IniWrite, %AHKPath%, %IniFile%, Settings, AHKPath
	IniWrite, %OwnHotKey%, %IniFile%, Settings, OwnHotKey
ExitApp:
	ExitApp
Return
;#############   文件结束   #################################################
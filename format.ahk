#Include <Print>
#SingleInstance force

commentRegExp := '(^|\s+)\;.*'  ;注释的正则表达式

options2 :=
{
    insertSpaces: true,  ; 是否用空格
    tabSize: 4,       ; 空格缩进时的字符数
    preserveIndent: false, ; 空行也保留缩进
    allowedNumberOfEmptyLines: 1,  ;允许的最大连续空行数量（-1 表示不限制）
    indentCodeAfterLabel: 1,  ;允许的最大连续空行数量（-1 表示不限制）
    indentCodeAfterIfDirective: 1,  ;允许的最大连续空行数量（-1 表示不限制）
    trimExtraSpaces:true,   ;是否清理多余空格（用户配置）
    switchCaseAlignment:true
}
; =================================================================
; 函数定义: repeat
; 功能:     通过基础的循环和字符串连接，实现字符串的重复。
; 参数:
;   - TextToRepeat (字符串): 需要被重复的原始字符串。
;   - RepeatCount (整数):    需要重复的次数。
; 返回值:
;   - (字符串): 由 TextToRepeat 重复 RepeatCount 次组成的新字符串。
; =================================================================
repeat(TextToRepeat, RepeatCount)
{
    ; 1. 初始化一个空字符串，用于存放最终结果
    finalString := ""

    if (RepeatCount <= 0)
    {
        return finalString
    }
    ; 3. 循环 RepeatCount 次
    Loop RepeatCount
    {
        finalString .= TextToRepeat
    }
    return finalString
}
; 功能: 将数组元素用指定分隔符连接成字符串。
StrJoin(array, delimiter)
{
    str := ""
    for index, value in array
    {
        str .= (index > 1 ? delimiter : "") . value
    }
    return str
}
/**
 * 生成指定深度的缩进字符
 * 根据 VS Code 用户配置（空格/制表符缩进）生成对应格式的缩进
 * @param depth 缩进深度（几级缩进）
 * @param options 格式化选项，包含 insertSpaces（是否用空格）和 tabSize（空格缩进时的字符数）
 * @returns 缩进字符字符串（如 depth=2、tabSize=4 时返回"    "）
 */

buildIndentationChars(depth,options)
{
    return options.insertSpaces ? repeat(" ", depth * options.tabSize) : repeat("`t", depth)
}
/**
 * 生成带缩进的代码行（非最终保存版本，无换行符）
 * 处理空行的缩进保留逻辑，避免空行丢失缩进
 * @param indentationChars 缩进字符（由 buildIndentationChars 生成）
 * @param formattedLine 格式化后的行文本（无缩进）
 * @param preserveIndentOnEmptyString 空行是否保留缩进
 * @returns 带缩进的行文本（末尾无换行符）
 */

buildIndentedString(indentationChars,formattedLine,preserveIndentOnEmptyString)
{
    if (preserveIndentOnEmptyString)
    {
        ;保留空行缩进：即使行文本为空，也添加缩进
        return indentationChars . formattedLine
    }
    ;不保留空行缩进：非空行添加缩进，空行返回原文本（无缩进）
    return !trim(formattedLine)? formattedLine : indentationChars . formattedLine
}
/**
 * 生成带缩进的最终代码行（可直接保存，含正确换行符）
 * 整合缩进生成、空行处理、换行符添加逻辑，生成最终写入文档的行
 * @param lineIndex 当前行的索引（从0开始）
 * @param lastLineIndex 文档最后一行的索引（lineCount-1）
 * @param formattedLine 格式化后的行文本（无缩进、无换行符）
 * @param depth 缩进深度
 * @param options 完整格式化选项（含 preserveIndent 等）
 * @returns 带缩进和换行符的最终行文本（最后一行无换行符）
 */
buildIndentedLine(lineIndex, lastLineIndex, formattedLine, depth, options)
{
    ; 1. 生成当前深度的缩进字符
    indentationChars := buildIndentationChars(depth, options)
    ; 2. 生成带缩进的行文本（无换行符）
    indentedLine := buildIndentedString(indentationChars, formattedLine, options.preserveIndent)
    ; 3. 非最后一行添加换行符（避免文档末尾多余空行）
    if (lineIndex != lastLineIndex)
    {
        ; AHK 中使用 "`n" 作为换行符
        indentedLine .= "`n"
    }
    return indentedLine
}
/**
 * 检查一行中右括号（()）是否比左括号多
 * 用于判断代码块是否提前闭合，辅助缩进计算
 * @param line 待检查的行文本
 * @returns 右括号数量 > 左括号数量时返回 true，否则 false
 */

hasMoreCloseParens(line)
{
    openCount := 0, closeCount := 0
    startPos := 1
    if !InStr(line, ")")
    {
        return false
    }
    ; 计算左括号数量
    while (pos := InStr(line, "(", , startPos))
    {
        openCount++
        startPos := pos + 1
    }
    ; 重置起始位置，计算右括号数量
    startPos := 1
    while (pos := InStr(line, ")", , startPos))
    {
        closeCount++
        startPos := pos + 1
    }
    return closeCount > openCount
}
/**
 * 检查一行中左括号（()）是否比右括号多
 * 用于判断代码块是否未闭合，辅助缩进计算
 * @param line 待检查的行文本
 * @returns 左括号数量 > 右括号数量时返回 true，否则 false
 */
hasMoreOpenParens(line)
{
    openCount := 0, closeCount := 0
    startPos := 1
    if !InStr(line, "(")
    {
        return false
    }
    ; 计算左括号数量
    while (pos := InStr(line, "(", , startPos))
    {
        openCount++
        startPos := pos + 1
    }
    ; 重置起始位置，计算右括号数量
    startPos := 1
    while (pos := InStr(line, ")", , startPos))
    {
        closeCount++
        startPos := pos + 1
    }
    return openCount > closeCount
}
/**
 * 净化代码行：移除注释、字符串字面量、代码块等干扰内容，保留核心语法结构
 * 用于分析代码行的语法类型（如是否为控制流语句、赋值语句）
 * @param original 原始代码行
 * @returns 净化后的代码行（仅保留核心语法关键字）
 */
purify(original)
{
    ; // 空行直接返回
    if (!original)
    {
        return ""
    }
    ; AHK 内置命令列表， 用于区分「命令」和「函数调用」（命令后无括号，函数后有括号）
    commandList := [
    "autotrim", "blockinput", "click", "clipwait", "control", "controlclick",
    "controlfocus", "controlget", "controlgetfocus", "controlgetpos", "controlgettext",
    "controlmove", "controlsend", "controlsendraw", "controlsettext", "coordmode",
    "critical", "detecthiddentext", "detecthiddenwindows", "drive", "driveget",
    "drivespacefree", "edit", "envadd", "envdiv", "envget", "envmult", "envset",
    "envsub", "envupdate", "exit", "exitapp", "fileappend", "filecopy", "filecopydir",
    "filecreatedir", "filecreateshortcut", "filedelete", "fileencoding", "filegetattrib",
    "filegetshortcut", "filegetsize", "filegettime", "filegetversion", "fileinstall",
    "filemove", "filemovedir", "fileread", "filereadline", "filerecycle",
    "filerecycleempty", "fileremovedir", "fileselectfile", "fileselectfolder",
    "filesetattrib", "filesettime", "formattime", "getkeystate", "groupactivate",
    "groupadd", "groupclose", "groupdeactivate", "gui", "guicontrol", "guicontrolget",
    "hotkey", "imagesearch", "inidelete", "iniread", "iniwrite", "input", "inputbox",
    "keyhistory", "keywait", "listhotkeys", "listlines", "listvars", "menu",
    "mouseclick", "mouseclickdrag", "mousegetpos", "mousemove", "msgbox", "onexit",
    "outputdebug", "pause", "pixelgetcolor", "pixelsearch", "postmessage", "process",
    "progress", "random", "regdelete", "regread", "regwrite", "reload", "run",
    "runas", "runwait", "send", "sendevent", "sendinput", "sendlevel", "sendmessage",
    "sendmode", "sendplay", "sendraw", "setbatchlines", "setcapslockstate",
    "setcontroldelay", "setdefaultmousespeed", "setenv", "setformat", "setkeydelay",
    "setmousedelay", "setnumlockstate", "setregview", "setscrolllockstate",
    "setstorecapslockmode", "settimer", "settitlematchmode", "setwindelay",
    "setworkingdir", "shutdown", "sleep", "sort", "soundbeep", "soundget",
    "soundgetwavevolume", "soundplay", "soundset", "soundsetwavevolume", "splashimage",
    "splashtextoff", "splashtexton", "splitpath", "statusbargettext", "statusbarwait",
    "stringcasesense", "stringgetpos", "stringleft", "stringlen", "stringlower",
    "stringmid", "stringreplace", "stringright", "stringsplit", "stringtrimleft",
    "stringtrimright", "stringupper", "suspend", "sysget", "thread", "tooltip",
    "transform", "traytip", "urldownloadtofile", "winactivate", "winactivatebottom",
    "winclose", "winget", "wingetactivestats", "wingetactivetitle", "wingetclass",
    "wingetpos", "wingettext", "wingettitle", "winhide", "winkill", "winmaximize",
    "winmenuselectitem", "winminimize", "winminimizeall", "winminimizeallundo",
    "winmove", "winrestore", "winset", "winsettitle", "winshow", "winwait",
    "winwaitactive", "winwaitclose", "winwaitnotactive"
    ]
    ;  临时变量，用于提取命令关键字
    cmdTrim := original

    ; 遍历命令列表，匹配行中的命令（命令后无括号，函数后有括号）
    ;例如："ControlSend, Control, Keys" → 提取为"ControlSend"；"ControlSend()" → 保留为函数调用
    for command in commandList
    {
        ; 这用来确保我们匹配的是命令本身，而不是函数调用（如 "MsgBox()"）

        pattern := "i)(^\s*" command "\b(?!\()).*"
        ; 使用 RegExMatch 进行不区分大小写的匹配
        ; 如果匹配成功，RegExMatch 返回匹配的起始位置（>0）
        if (RegExMatch(original, pattern))
        {
            ; 提取命令关键字
            cmdTrim := RegExReplace(original, pattern, "$1")
            break ; 匹配到一个命令后，立即退出循环
        }
    }
    ; --- 净化过程 ---
    pure := RegExReplace(cmdTrim,'".*?"', '""') ;替换字符串字面量为空字符串（如"abc"→""），避免干扰语法分析
    pure := replaceAll(pure,'{[^{}]*}', '') ;移除匹配的代码块（如{...}），避免大括号干扰
    pure := RegExReplace(pure,'\s+', ' ')  ;合并多个空白为单个空格（统一空格格式）
    pure := RegExReplace(pure,commentRegExp, '') ;移除注释（必须最后执行，避免误删字符串中的";"）
    pure :=Trim(pure)
    return pure
}
/**
 * 判断当前行是否为「单行控制流语句」（下一行需缩进）
 * 单行控制流语句指 if/loop/while 等无大括号的语句，下一行代码需缩进
 * 例：if (var) → 下一行 MsgBox 需缩进
 * @param text 净化后的当前行文本（由 purify 生成）
 * @returns 是单行控制流语句则返回 true，否则 false
 */
nextLineIsOneCommandCode(text)
{
    ; 需触发下一行缩进的控制流关键字列表
    oneCommandList := [
    "ifexist", "ifinstring", "ifmsgbox", "ifnotexist", "ifnotinstring",
    "ifwinactive", "ifwinexist", "ifwinnotactive", "ifwinnotexist",
    "if", "else", "loop", "for", "while", "catch"
    ]

    ; 遍历关键字列表，匹配当前行是否为单行控制流语句
    for oneCommand in oneCommandList
    {
        ; 匹配规则：
        ;1. 行首可选 "}"（如"} else"场景）
        ; 2. 关键字（如if），且后接单词边界（避免匹配子串）
        ;3. 关键字后不能跟":"（排除标签，如"If:"是标签而非控制流）。
        pattern := "^}?\s*" . oneCommand . "\b(?!:)"
        if (RegExMatch(text, pattern))
        {
            return true
        }
    }
    return false
}
/**
 * 清理文档中的空行：移除开头空行 + 限制连续空行数量
 * 按用户配置保留指定数量的连续空行，避免空行过多或过少
 * @param docString 待处理的文档字符串
 * @param allowedNumberOfEmptyLines 允许的最大连续空行数量（-1 表示不限制）
 * @returns 清理空行后的文档字符串
 */
removeEmptyLines(docString,allowedNumberOfEmptyLines)
{
    if (allowedNumberOfEmptyLines = -1)
    {
        return docString   ;不限制空行，直接返回原字符串
    }
    ; 正则：匹配「1个换行符 + N个（空白+换行符）」（N ≥ 允许的空行数量）
    ; \s*?：非贪婪匹配空白（避免匹配换行符外的其他空白）
    emptyLines := "\n(\s*?\n){" allowedNumberOfEmptyLines ",}"
    if (RegExMatch(docString,emptyLines,&match))
    {
        firstName := match[1]
    }
    else
    {
        firstName := ""
    }
    replacement := "`n"
    replacement.=Repeat(firstName,allowedNumberOfEmptyLines)

    docString := RegExReplace(docString, emptyLines, replacement)
    docString := RegExReplace(docString, "^\s*\n+")
    return docString
}
/**
 * 清理行中的多余空格（仅保留单词间单个空格）
 * 按用户配置决定是否清理，避免代码中空格混乱
 * @param line 待处理的行文本
 * @param trimExtraSpaces 是否清理多余空格（用户配置）
 * @returns 清理空格后的行文本
 */
trimExtraSpaces(line,trimExtraSpaces)
{
    return trimExtraSpaces ? RegExReplace(line, " {2,}"," ") : line
}
/**
 * 计算一行中未匹配的大括号数量（{ 或 }）
 * 先移除嵌套的代码块，再统计目标大括号数量，避免嵌套干扰
 * @param line 待处理的行文本
 * @param braceChar 目标大括号（{ 或 }）
 * @returns 未匹配的目标大括号数量
 */
braceNumber(line, braceChar)
{
    lineWithoutBlocks := replaceAll(line, "{[^{}]*}", '') ;// 1. 移除所有嵌套代码块（{...}），避免内部大括号干扰
    braceCount := StrSplit(lineWithoutBlocks, braceChar).Length - 1
    if(braceCount<0)
        braceCount :=0
    return braceCount
}
/**
 * 【赋值语句等号对齐主函数】
 * 将多行赋值语句的 `=` 或 `:=` 运算符对齐到同一列，确保代码视觉一致性
 * @param text 待对齐的赋值语句数组（每行一个赋值语句）
 * @returns 等号对齐后的赋值语句数组
 */
alignTextAssignOperator(text)
{
    ; --- 步骤 1: 计算所有赋值语句中「第一个等号」的最右侧位置 ---

    ; 创建一个数组来存储每行标准化后等号的位置
    equalSignPositions := []
    originalText := StrSplit(text, "`n")
    for line in originalText
    {
        ; 调用辅助函数标准化行格式
        normalizedLine := normalizeLineAssignOperator(line)
        ; 找到标准化行中第一个 '=' 的索引
        equalIndex := InStr(normalizedLine, "=")
        equalSignPositions.Push(equalIndex)
    }
    ; 使用 Max 函数找到所有位置中的最大值，这就是我们的「目标对齐位置」
    ; Max 函数可以接受一个数组作为参数，通过 * 解包
    maxPosition := Max(equalSignPositions*)

    ; 如果所有行都没有等号，maxPosition 会是 -1，直接返回原数组
    if (maxPosition < 1)
    {
        return text
    }
    ; --- 步骤 2: 按最右侧位置对齐所有等号 ---
    ; 创建一个新数组来存储对齐后的行
    alignedTextstr := []

    ; 再次遍历输入的每一行
    for line in originalText
    {
        ; 调用辅助函数来对齐当前行
        alignedLine := alignLineAssignOperator(line, maxPosition)
        ; 将对齐后的行添加到新数组中
        alignedTextstr.Push(alignedLine)
    }
    alignedText:=""
    ; 返回最终对齐后的字符串数组
    for line in alignedTextstr
    {
        alignedText .= line "`n"
    }
    return alignedText
}
/**
 * 【赋值语句标准化】
 * 清理赋值语句中的干扰内容，统一等号前后格式，为等号对齐做前置准备
 * 核心目标：确保每行赋值语句的等号格式一致，避免注释、多余空格影响对齐计算
 * @param original 原始赋值语句行（可能含注释、等号前后空格不统一、单词间多余空格）
 * @returns 标准化后的语句（无注释、等号前后各1个空格、单词间仅1个空格）
 */
normalizeLineAssignOperator(original)
{
    original := RegExReplace(original, "(?<!`);.+", '') ;1. 移除单行注释：跳过转义的分号 `;`（如字符串中的 `a`;b`，避免误删内容）
    original := RegExReplace(original, "(?<=\S) {2,}(?=\S)", ' ') ;2. 清理单词间多余空格：保留行首缩进（影响代码层级）和行尾空格（影响注释对齐）
    ;仅将「非行首/行尾的连续2个以上空格」替换为1个空格
    original := RegExReplace(original, "\s*(:?=)", ' $1') ;3. 统一等号前空格：无论原是否有空格，均确保等号（含 `:=`）前有1个空格
    original := RegExReplace(original, "(:?=)\s*", '$1 ') ;4. 统一等号后空格：无论原是否有空格，均确保等号（含 `:=`）后有1个空格 更改
    return original
}
/**
 * 【单行赋值等号对齐】
 * 根据目标位置为单行赋值语句补充空格，使等号对齐，并恢复原注释（避免丢失注释）
 * @param original 原始赋值语句行（含注释）
 * @param targetPosition 等号的目标对齐位置（所有行的最右等号索引）
 * @returns 等号对齐后的完整语句（含原注释、无行尾多余空格）
 */
alignLineAssignOperator(original, targetPosition)
{
    ; 步骤1：提取并保存行尾注释（后续需恢复）
    comment := ""  ; 存储提取的注释
    if (RegExMatch(original, "(;.+)", &matchObj))
    {
        comment := matchObj[1]  ; 保存提取的注释（如 "; This is a comment"）
    }
    ; 步骤2：标准化原始行（清理注释、统一等号前后空格，便于计算

    normalizedLine := normalizeLineAssignOperator(original)

    ; 步骤3：获取当前行等号的原始位置（用于计算需补充的空格数）

    currentEqIndex := InStr(normalizedLine, "=")

    if (currentEqIndex < 0)
    {
        return original
    }
    ; --------------------------
    ; 步骤4：补充空格使等号移动到目标位置
    ; --------------------------
    ; 计算需补充的空格数量：目标位置 - 当前等号索引 + 1（与原 TS 逻辑一致）
    spacesCount := targetPosition - currentEqIndex + 1
    ; 生成对应数量的空格（使用 StrRepeat 重复空格字符）
    spacesToAdd := Repeat(" ", spacesCount)
    ; 替换等号前的 1 个空格为计算出的空格（使等号移动到目标位置）
    ; 正则 /\s(?=:?=)/：匹配等号（含 :=）前的 1 个空格（正向预查确保是等号前的空格）
    alignedLine := RegExReplace(normalizedLine, "\s(?=:?=)", spacesToAdd)

    ; --------------------------
    ; 步骤5：恢复行尾注释 + 去除行尾多余空格
    ; --------------------------
    ; 拼接对齐后的语句和注释，再用 TrimEnd 清理行尾多余空格（避免格式混乱）
    local finalLine := (alignedLine . comment)
    finalLine :=RTrim(finalLine)

    return finalLine
}
/**
 * 【递归文本替换】
 * 解决原生 `String.replace` 无法处理嵌套/连续匹配的问题（如嵌套 `{}`、`""`）
 * 原理：循环替换直到文本长度不变（表示无新匹配项）
 * @warning 风险提示：搜索内容与替换内容长度必须不同，否则会无限循环
 * @param text 待处理文本
 * @param search 匹配规则（需带全局匹配标志 `g`，否则仅替换第一次匹配）
 * @param replace 替换文本
 * @return 完全替换后的文本（无剩余匹配项）
 */
replaceAll(text,search,replace)
{
    OutputVarCount:=1
    while (OutputVarCount)
    {
        text := RegExReplace(text, search,replace, &OutputVarCount)
    }
    return text
}
/**
 * 【控制流嵌套深度管理器】
 * 跟踪 if/loop/while 等控制流语句的缩进层级，处理嵌套代码块的缩进计算
 * 核心数据结构：用数组记录层级，`-1` 作为代码块分隔符（对应 `{}`），数字表示缩进深度
 * 作用：解决嵌套控制流的缩进回溯问题（如多层 if-else 后正确恢复缩进）
 */
class FlowOfControlNestDepth
{
    ; 层级数组：
    ; - 元素为 `-1`：代码块分隔符（标记 `{` 的位置，用于识别代码块边界）
    ; - 元素为数字：控制流语句的缩进深度（如 if 语句所在的层级）
    ; - 初始值 `[-1]`：确保数组始终非空，避免索引越界异常
    depth := []

    ; 构造函数：初始化层级数组（支持传入已有数组恢复历史状态，如块注释退出后恢复控制流）
    ; 参数 array：可选初始数组（用于恢复之前的控制流层级，避免状态丢失）
    __New(array?)
    {
        if (IsSet(array) && IsObject(array) && array.Length > 0)
        {
            this.depth := array.Clone()  ; 克隆传入的数组，避免外部修改影响内部状态
        }
        else
        {
            this.depth := [-1]  ; 初始默认值
        }
    }
    ; 【进入代码块】
    ; 对应代码中出现 `{` 时，添加分隔符标记代码块边界（每个 `{` 对应一个 `-1`）
    ; 参数 openBraceNum：左大括号 `{` 的数量（即进入的代码块数量，支持多层嵌套）
    ; 返回：更新后的层级数组
    enterBlockOfCode(openBraceNum)
    {
        Loop openBraceNum
        {
            this.depth.Push(-1)  ; 为每个 `{` 添加分隔符
        }
        return this.depth
    }
    LastIndexOf(arr, target)
    {
        Loop arr.Length
        {
            currentIndex := arr.Length - (A_Index - 1)
            if (arr[currentIndex] = target)
            {
                return currentIndex
            }
        }
        return -1
    }
    ; 【退出代码块】
    ; 对应代码中出现 `}` 时，回溯到上一层代码块边界（删除当前块的层级记录）
    ; 示例：`[-1, 0, -1, 1, 2]`（两层嵌套）→ 退出1个代码块后 → `[-1, 0]`
    ; 参数 closeBraceNum：右大括号 `}` 的数量（即退出的代码块数量，支持多层退出）
    ; 返回：更新后的层级数组
    exitBlockOfCode(closeBraceNum)
    {
        Loop closeBraceNum
        {
            lastDashIndex := this.LastIndexOf(this.depth, -1)
            this.depth.RemoveAt(lastDashIndex, this.depth.Length- lastDashIndex+1)
        }
        this.restoreEmptyDepth()
        return this.depth
    }
    ; 【获取当前最内层层级】
    ; 返回层级数组的最后一个元素（当前最内层的分隔符或缩进深度）
    ; 返回值：最后一个元素（数字表示缩进深度，`-1` 表示分隔符）
    last()
    {
        return this.depth[this.depth.Length]  ; AHK v2 数组索引从 1 开始
    }
    ; 【添加层级记录】
    ; 向层级数组添加一个控制流语句的缩进深度（如记录 if 语句的层级）
    ; 参数 items：要添加的层级值（数字）
    ; 返回：添加后的数组长度（便于后续状态判断）
    push(items)
    {
        return this.depth.Push(items)
    }
    ; 【移除最内层记录】
    ; 从层级数组移除最后一个元素（回溯层级，如 else 对应 if 的层级删除）
    ; 返回：被移除的元素（数字或 `-1`）
    pop()
    {
        if (this.depth.Length = 0)
        {
            this.restoreEmptyDepth()  ; 确保数组非空
        }
        result := this.depth.Pop()
        ; 移除后若数组为空，恢复初始状态（避免后续操作异常）
        this.restoreEmptyDepth()
        return result
    }
    ; 【恢复当前代码块层级】
    ; 删除分隔符后的多余层级，回溯到当前代码块的正确层级（用于控制流嵌套结束后）
    ; 示例：`[-1, 0, -1, 1, 2]` → 恢复后 → `[-1, 0, -1]`，返回被移除的第一个层级 `1`
    ; 返回：恢复前分隔符后的第一个层级值（用于判断缩进回溯目标）
    restoreDepth()
    {
        ; 找到最后一个分隔符 `-1` 的位置，其下一个元素即为当前块的初始层级
        index := this.LastIndexOf(this.depth, -1)+1
        element := (index <= this.depth.Length) ? this.depth[index] : 0
        ; 删除分隔符后的所有元素（清理当前块的嵌套层级）
        if (index <= this.depth.Length)
        {
            this.depth.RemoveAt(index, this.depth.Length- index+1)
        }
        return element
    }
    ; 【恢复空数组初始状态】
    ; 若层级数组被清空（如异常的多 `}`），重置为初始值 `[-1]`，避免后续操作报错
    restoreEmptyDepth()
    {
        if (this.depth.Length = 0)
        {
            this.depth := [-1]
        }
    }
}
/**
 * 【单行注释对齐】
 * 使单行注释（以 `;` 开头）与上一行代码的缩进保持一致，避免注释位置混乱
 * 处理场景：空行后的注释、代码块后的注释等，确保注释缩进跟随代码层级
 * @param stringToFormat 待处理的文档字符串（完整脚本）
 * @param options VS Code 格式化选项（含缩进类型、缩进大小、是否保留原缩进）
 * @return 注释对齐后的文档字符串
 */
alignSingleLineComments(stringToFormat, options)
{
    ; --- 1. 初始化变量 ---
    local depth := 0               ; 当前代码行的缩进深度
    local prevLineDepth := 0       ; 上一行非空代码的缩进深度

    ; 使用 StrSplit 按行分割字符串。`\R` 是一个通用换行符转义序列，可匹配 \n, \r\n 等。
    local lines := StrSplit(stringToFormat, "`n")

    ; --- 2. 从后向前遍历行 ---
    ; 这样可以确保处理当前行时，上一行代码的深度已经被计算和记录。
    Loop lines.Length
    {
        ; 计算当前循环的 0-based 索引 (从后向前)
        local i := lines.Length - A_Index + 1
        local line := lines[i]

        ; --- 3. 判断是否为空行或纯注释行 ---
        ; 调用辅助函数 purify 移除代码和注释内容，只保留结构字符
        local purifiedLine := purify(line)
        local emptyLine := (purifiedLine == "")

        if (emptyLine)
        {
            ; --- 4. 处理空行或纯注释行 ---
            ; 使用上一行非空代码的深度来生成缩进字符
            local indentationChars := buildIndentationChars(prevLineDepth, options)

            ; 调用辅助函数重新构建行：新缩进 + 清理后的原始行内容
            lines[i] := buildIndentedString(indentationChars, Trim(line), options.preserveIndent)
        }
        else
        {
            ; --- 5. 处理非空代码行 ---
            ; 计算当前行的缩进深度
            depth := calculateDepth(line, options)

            ; --- 特殊处理：右大括号 `}` ---
            ; 如果当前行是 `}`，需要增加深度，以确保其后面的注释能正确对齐到上一层级
            if (RegExMatch(line, "^\s*}"))
            {
                ; 调用辅助函数计算该行未匹配的右大括号数量
                local braceNum := braceNumber(purifiedLine, "}")
                depth += braceNum
            }
            ; 更新 "上一行代码深度" 变量，供下一行（向前的行）使用
            prevLineDepth := depth
        }
    }
    alignedText:=""
    ; 返回最终对齐后的字符串数组
    for line in lines
    {
        alignedText .= line "`n"
    }
    return alignedText
    ; --- 6. 重新拼接行并返回 ---
}
/**
 * 【计算代码行缩进深度】
 * 将代码行的缩进字符（空格/制表符）转换为层级（数字），统一缩进计算标准
 * @param text 待计算的代码行
 * @param options VS Code 格式化选项（含缩进类型：空格/制表符，缩进大小）
 * @return 缩进深度（数字，如 2 表示 2 级缩进）
 */

calculateDepth(line, options)
{
    ; 1. 提取行首的所有空白字符（空格或制表符）
    if (!RegExMatch(line, "^(\s+)", &match))
    {
        return 0 ; 没有缩进
    }
    local whitespace := match[1]

    ; 2. 根据 options 计算深度
    if (options.insertSpaces)
    {
        ; 使用空格：深度 = 空格总数 / 每个层级的空格数
        return StrLen(whitespace) / options.tabSize
    }
    else
    {
        ; 使用制表符：深度 = 制表符的数量
        return StrLen(whitespace)
    }
}
internalFormat(stringToFormat, options)
{
    local formattedString := ""  ; 最终格式化后的字符串（逐步拼接）

    ; ==============================
    ; 1. 缩进相关状态变量（管理代码层级）
    ; ==============================
    local depth := 0              ; 当前行的缩进深度（初始为 0，无缩进）
    local prevLineDepth := 0      ; 上一行的缩进深度（用于对齐和回溯）
    local tagDepth := 0           ; 标记深度：控制 Return/Exit/Label/Hotkey 的缩进规则
    ; - 0：特殊语句可取消缩进；>0：按标记深度跳转缩进

    ; ==============================
    ; 2. 控制流相关状态变量（处理 if/loop/while 等嵌套）
    ; ==============================
    local oneCommandCode := false           ; 当前行是否为「单行控制流」（下一行需缩进）
    local prevLineIsOneCommandCode := false ; 上一行是否为「单行控制流」（续行处理）
    local detectOneCommandCode := true      ; 是否检测单行控制流（避免大括号后重复缩进）
    ; 控制流深度管理器（复用之前实现的 FlowOfControlNestDepth 类）
    local ifDepth := FlowOfControlNestDepth()   ; if-else 嵌套深度管理器（单独管理）
    local focDepth := FlowOfControlNestDepth()  ; 通用控制流（loop/while/for）深度管理器

    ; ==============================
    ; 3. 赋值对齐相关状态变量
    ; ==============================
    local alignAssignment := false       ; 是否启用赋值对齐（由格式化指令控制）
    local assignmentBlock := []          ; 存储待对齐的赋值语句块（多行赋值）

    ; ==============================
    ; 4. 续行相关状态变量
    ; ==============================
    local continuationSectionExpression := false  ; 是否处于「表达式续行」（对象、条件表达式）
    local continuationSectionTextFormat := false   ; 是否处于「格式化文本续行」（(LTrim 开头）
    local continuationSectionTextNotFormat := false ; 是否处于「原始文本续行」（保留用户格式）
    local openBraceIndent := false        ; 左大括号是否触发缩进（对象续行回溯）
    local deferredOneCommandCode := false ; 延迟的单行控制流（续行后恢复缩进）
    local openBraceObjectDepth := -1      ; 对象续行中左大括号的缩进深度（回溯用）

    ; ==============================
    ; 5. 块注释相关状态变量
    ; ==============================
    local blockComment := false           ; 是否处于块注释中（/* ... */）
    local blockCommentIndent := ""        ; 块注释的基础缩进（保留原结构）
    local formatBlockComment := false     ; 是否格式化块注释内容（由指令控制）
    ; 块注释前的状态备份（退出时恢复）
    local preBlockCommentDepth := 0
    local preBlockCommentTagDepth := 0
    local preBlockCommentPrevLineDepth := 0
    local preBlockCommentOneCommandCode := false
    local preBlockCommentIfDepth := FlowOfControlNestDepth()
    local preBlockCommentFocDepth := FlowOfControlNestDepth()

    ; ==============================
    ; 6. 配置别名（简化代码，避免重复访问 options）
    ; ==============================
    local indentCodeAfterLabel := options.indentCodeAfterLabel
    local indentCodeAfterIfDirective := options.indentCodeAfterIfDirective
    local trimSpaces := options.trimExtraSpaces
    local switchCaseAlignment := options.switchCaseAlignment
    ; ==============================
    ; 7. 正则表达式（复用避免重复创建，使用 AHK 原生 RegEx 对象）
    ; ==============================
    ; 赋值对齐指令：;@AHK++AlignAssignmentOn/Off
    local ahkAlignAssignmentOn := false
    local ahkAlignAssignmentOff := true
    ; 块注释格式化指令：;@AHK++FormatBlockCommentOn/Off
    local ahkFormatBlockCommentOn := false
    local ahkFormatBlockCommentOff := true
    ; 续行匹配：以 and/or/not/运算符/逗号等开头的行（需与上一行合并）
    local continuationSection := "^(((and|or|not)\b)|[\^!~?:&<>=.,|]|\+(?!\+)|-(?!-)|\/(?!\*)|\*(?!\/))"
    ; 标签匹配（如 Label:）：行首非空白/逗号/反引号，结尾为 :
    local label := "^[^\s\t,`]+(?<!:):$"
    ; 热键/热字符串匹配（无代码，如 F1::）：结尾为 ::
    local hotkey := "^.+::$"
    ; 单行热键匹配（含代码，如 F1::Run Notepad）：包含 :: 且非行尾
    local hotkeySingleLine := "^.+::"
    ; #If 指令匹配（#IfWinActive/#IfWinNotActive/#IfWinExist/#IfWinNotExist/#If）
    local sharpDirective := '#(ifwinactive|ifwinnotactive|ifwinexist|ifwinnotexist|if)'
    ; Switch 的 Case/Default 匹配（如 case 1:、default:）
    local switchCaseDefault := "^(case\s*.+?:|default:)\s*.*"
    ;是否进入Switch语句
    local switchflag := false
    ;是否Switch的第一个 Case语句
    local switchcaseflag:= false

    ; 注释提取正则：匹配行中第一个 ; 及其后的所有内容
    ;local commentRegExp := "(;.*)"

    stringToFormat :=FormatAllmanStyle(stringToFormat)
    ; ==============================
    ; 初始化：按行拆分文档（支持 \n/\r\n/\r 换行符）
    ; ==============================
    local lines := StrSplit(stringToFormat, "`r`n")  ; AHK v2 StrSplit 支持 \R 匹配所有换行符
    ; ==============================
    ; 核心流程：逐行处理每一行
    ; ==============================
    for originalLine in lines
    {
        lineIndex:=A_Index
        local purifiedLine := StrLower(purify(originalLine))  ; 净化行（去注释/字符串，转小写）
        local comment := ""
        ; 提取行尾注释
        if (RegExMatch(originalLine, commentRegExp, &matchObj))
        {
            comment := matchObj[0]
        }
        ; 移除注释 → 清理多余空格 → 恢复注释 → 修剪行首尾空格
        local formattedLine := StrReplace(originalLine, comment, "")  ; 移除注释

        formattedLine := trimExtraSpaces(formattedLine, trimSpaces)   ; 清理多余空格

        formattedLine := formattedLine . comment                      ; 恢复注释

        formattedLine := Trim(formattedLine)                          ; 修剪行首尾空格
        ; 判断是否为空行/纯注释行（净化后无代码内容）
        local emptyLine := (purifiedLine == "")

        detectOneCommandCode := true  ; 默认开启单行控制流检测

        ; 统计本行左/右大括号数量（用于代码块嵌套处理）
        local openBraceNum := braceNumber(purifiedLine, "{")
        local closeBraceNum := braceNumber(purifiedLine, "}")

        ; =====================================================================
        ; |                            本行核心处理                            |
        ; =====================================================================

        ; --------------------------
        ; 1. 空行处理：检测格式化指令（赋值对齐/块注释格式化关闭）
        ; --------------------------
        if (emptyLine)
        {
            ; 赋值对齐关闭指令：对齐已收集的赋值块并输出
            if (alignAssignment && ahkAlignAssignmentOff)
            {
                alignAssignment := false
                ; 调用赋值对齐函数处理已收集的块
                assignmentBlock := alignTextAssignOperator(assignmentBlock)
                ; 输出对齐后的赋值块（按原行号顺序）
                for alignedFormattedLine in assignmentBlock
                {
                    local lineNum := lineIndex - assignmentBlock.Length + A_Index
                    formattedString .= buildIndentedLine(lineNum, lines.length, alignedFormattedLine, depth, options)
                }
                assignmentBlock := []  ; 重置赋值块
            }
            ; 块注释格式化关闭指令
            if (formatBlockComment && ahkFormatBlockCommentOff)
            {
                formatBlockComment := false
            }
        }
        ; --------------------------
        ; 2. 赋值对齐：如果启用了赋值对齐，收集赋值行
        ; --------------------------
        if (alignAssignment)
        {
            assignmentBlock.Push(formattedLine)
            ; 若未到最后一行，继续收集（不输出）
            if (lineIndex != (lines.length))
            {
                continue
            }
            ; 如果到文件末尾还没遇到关闭指令，对齐剩余的赋值块

            for alignedFormattedLine in assignmentBlock
            {
                local lineNum := lineIndex - assignmentBlock.Length + A_Index
                formattedString .= buildIndentedLine(lineNum, lines.length, alignedFormattedLine, depth, options)
            }
            assignmentBlock := []  ; 重置赋值块
        }
        ; --------------------------
        ; 3. 块注释开始处理
        ; --------------------------
        if (!blockComment && RegExMatch(originalLine, "^\s*\/\*"))
        {
            blockComment := true
            ; 提取块注释的基础缩进（行首空格 + /* 前的空格）
            if (RegExMatch(originalLine, "(^\s*)\/\*", &matchObj))
            {
                blockCommentIndent := matchObj[1]
            }
            else
            {
                blockCommentIndent := ""  ; 若此处设为空，后续调用 InStr 需先判断
            }
            ; 若开启块注释格式化，备份当前状态（退出时恢复）
            if (formatBlockComment)
            {
                preBlockCommentDepth := depth
                preBlockCommentTagDepth := tagDepth
                preBlockCommentPrevLineDepth := prevLineDepth
                preBlockCommentOneCommandCode := oneCommandCode
                preBlockCommentIfDepth := ifDepth  ; 备份 if 深度管理器
                preBlockCommentFocDepth := focDepth ; 备份通用控制流深度管理器
                ; 重置块注释内的缩进状态（避免嵌套干扰）
                tagDepth := depth
                prevLineDepth := depth
                oneCommandCode := false
                ifDepth := FlowOfControlNestDepth()
                focDepth := FlowOfControlNestDepth()
            }
        }
        ; --------------------------
        ; 4. 块注释处理：块注释内容（保留原格式或格式化）
        ; --------------------------
        if (blockComment)
        {
            ; 不格式化块注释：保留用户原始缩进（仅移除基础缩进避免重复）
            if (!formatBlockComment)
            {
                local blockCommentLine := ''
                ; 检查当前行是否以 blockCommentIndent 开头
                ; 判断 originalLine 是否以 blockCommentIndent 开头
                if (blockCommentIndent = "")
                {
                    ; 若 blockCommentIndent 为空，直接取整行
                    blockCommentLine := originalLine
                }
                else if (InStr(originalLine, blockCommentIndent,, 1) = 1)
                {
                    ; 若开头匹配，截取从 blockCommentIndent 长度之后的部分
                    len := StrLen(blockCommentIndent)  ; 获取前缀长度
                    blockCommentLine := SubStr(originalLine, len + 1)  ; 从长度+1位置开始截取（AHK索引从1开始）
                }
                else
                {
                    ; 不匹配时，取整行
                    blockCommentLine := originalLine
                }
                formattedString .= buildIndentedLine(lineIndex, lines.length, RTrim(blockCommentLine), depth, options)
            }
            ; 检测块注释结束（*/）：恢复状态
            if (RegExMatch(originalLine, "^\s*\*\/"))
            {
                blockComment := false
                ; 若开启过块注释格式化，恢复进入前的状态
                if (formatBlockComment)
                {
                    depth := preBlockCommentDepth
                    tagDepth := preBlockCommentTagDepth
                    prevLineDepth := preBlockCommentPrevLineDepth
                    oneCommandCode := preBlockCommentOneCommandCode
                    ifDepth := preBlockCommentIfDepth
                    focDepth := preBlockCommentFocDepth
                }
            }
            ; 不格式化块注释时，跳过后续处理（直接进入下一行）
            if (!formatBlockComment)
            {
                continue
            }
        }
        ; --------------------------
        ; 5. 单行注释处理：非格式化指令的纯注释行（对齐到上一行层级）
        ; --------------------------
        if (emptyLine && !RegExMatch(comment, ahkAlignAssignmentOn) && !RegExMatch(comment, ahkAlignAssignmentOff) && !RegExMatch(comment, ahkFormatBlockCommentOn) && !RegExMatch(comment, ahkFormatBlockCommentOff))
        {
            ; 纯注释行：按当前深度输出（后续 alignSingleLineComments 会进一步对齐）
            formattedString .= buildIndentedLine(lineIndex, lines.length, formattedLine, 0, options)
            continue
        }
        ; --------------------------
        ; 6. 原始文本续行开始
        ; --------------------------
        if (RegExMatch(purifiedLine, "^ \( (?!::) (?!.*\bltrim\b) ",))
        {
            continuationSectionTextNotFormat := true
        }
        ; 原始文本续行内容（保留用户格式）
        if (continuationSectionTextNotFormat)
        {
            formattedString := RTrim(originalLine) . "`n"  ; 保留行尾，避免多余空格
            ; 检测续行结束（) 开头）：重置状态
            if (RegExMatch(purifiedLine, "^\)"))
            {
                continuationSectionTextNotFormat := false
            }
            return
        }
        ; --------------------------
        ; 7. 续行处理：格式化文本续行结束（(LTrim 开头，恢复缩进）
        ; --------------------------
        if (continuationSectionTextFormat && RegExMatch(purifiedLine, "^\)"))
        {
            continuationSectionTextFormat := false
            depth--  ; 退出文本块，缩进减 1
        }
        ; 格式化文本续行内容：按当前深度缩进（统一格式）
        if (continuationSectionTextFormat)
        {
            formattedString .= buildIndentedLine(lineIndex, lines.length, Trim(originalLine), depth, options)
            continue
        }
        ; --------------------------
        ; 8. 续行处理：表达式/对象续行（and/or/运算符开头，调整缩进）
        ; --------------------------
        if (RegExMatch(purifiedLine, continuationSection) && !RegExMatch(purifiedLine, "::"))
        {
            continuationSectionExpression := true
            ; 左大括号触发的缩进：回溯到上一行深度
            if (openBraceIndent)
            {
                depth--
                openBraceObjectDepth := prevLineDepth
            }
            ; 单行控制流延迟处理：暂减缩进，后续恢复
            if (oneCommandCode)
            {
                deferredOneCommandCode := true
                oneCommandCode := false
                prevLineIsOneCommandCode := false
                depth--
            }
            ; 上一行是单行控制流：当前行需加缩进
            if (prevLineIsOneCommandCode)
            {
                oneCommandCode := true
                depth++
            }
            depth++
        }
        ; --------------------------
        ; 9. 续行处理：恢复延迟的单行控制流缩进
        ; --------------------------
        if (deferredOneCommandCode && !continuationSectionExpression)
        {
            deferredOneCommandCode := false
            oneCommandCode := true
            depth++  ; 恢复单行控制流的缩进
        }
        ; --------------------------
        ; 10. 处理右大括号（退出代码块）：退出代码块（右大括号 }，调整缩进和控制流深度）
        ; --------------------------
        if (closeBraceNum)
        {
            ; 通用控制流深度非分隔符：当前深度设为控制流最后一层深度
            if (focDepth.last() > -1)
            {
                depth := focDepth.last()
            }
            ; 退出 if/通用控制流的代码块（移除对应层级记录）
            ifDepth.exitBlockOfCode(closeBraceNum)
            focDepth.exitBlockOfCode(closeBraceNum)
            ; 非表达式续行：缩进随右大括号数量减少
            if (!continuationSectionExpression)
            {
                depth -= closeBraceNum
            }
            if(switchflag)
            {
                depth--
                switchflag:=false
            }
        }
        ; --------------------------
        ; 11. 代码块处理：进入代码块（左大括号 {，调整控制流状态）
        ; --------------------------
        if (openBraceNum)
        {
            ; 单行控制流或延迟单行控制流：调整状态避免重复缩进
            if ((oneCommandCode || deferredOneCommandCode) && !nextLineIsOneCommandCode(purifiedLine))
            {
                if (deferredOneCommandCode)
                {
                    deferredOneCommandCode := false  ; 清除延迟状态
                }
                else if (RegExMatch(purifiedLine, "^{"))  ; 左大括号开头：取消单行控制流缩进
                {
                    oneCommandCode := false
                    depth -= openBraceNum
                }
                ; 深度匹配通用控制流最后一层：移除该层记录
                if (depth = focDepth.last())
                {
                    focDepth.pop()
                }
            }
        }
        ; --------------------------
        ; 12. 控制流处理：退出嵌套（非续行、非单行控制流，回溯缩进）
        ; --------------------------
        if ((ifDepth.last() > -1 || focDepth.last() > -1) && !continuationSectionExpression && !oneCommandCode && (!blockComment || formatBlockComment))
        {
            ; else 语句：回溯到 if 上一层深度
            if (RegExMatch(purifiedLine, "^}? ?else\b(?!:)"))
            {
                depth := ifDepth.pop()
            }
            else if (!RegExMatch(purifiedLine, "^{") && !RegExMatch(purifiedLine, "^}"))
            {
                local restoreIfDepth := ifDepth.restoreDepth()
                local restoreFocDepth := focDepth.restoreDepth()
                ; 处理深度值存在的情况，取最小值
                ;原语句if (restoreIfDepth !== undefined &&restoreFocDepth !== undefined)
                if (restoreIfDepth!=0 && restoreFocDepth!=0)
                {
                    ;depth := Min(Number(restoreIfDepth), Number(restoreFocDepth))
                    depth := (restoreIfDepth < restoreFocDepth) ? restoreIfDepth : restoreFocDepth
                }
                else
                {
                    depth := restoreIfDepth!=0 ? restoreIfDepth : restoreFocDepth
                }
            }
        }
        ; --------------------------
        ; 13. 特殊指令处理：#If 指令（调整缩进和标记深度）
        ; --------------------------
        if (RegExMatch(purifiedLine, "^" . sharpDirective . "\b"))
        {
            ; 标记深度大于 0：当前深度减去标记深度（回溯到 #If 前层级）
            if (tagDepth > 0)
            {
                depth -= tagDepth
            }
            else
            {
                depth--  ; 标记深度为 0：深度减 1
            }
        }
        ; --------------------------
        ; 14. 特殊语句处理：Return/Exit/ExitApp（强制回溯到标签层级）
        ; --------------------------
        if (RegExMatch(purifiedLine, "^(return|exit|exitapp)\b") && tagDepth = depth)
        {
            tagDepth := 0  ; 重置标记深度
            depth--        ; 缩进减 1（回溯到标签前层级）
        }
        ; --------------------------
        ; 15. 特殊语句处理：Switch-Case/Default 或 Label/Hotkey（调整缩进）
        ; --------------------------
        if (RegExMatch(purifiedLine, "\bswitch\b"))
        {
            switchflag:=true
            switchcaseflag:=true
        }
        if (RegExMatch(purifiedLine, switchCaseDefault))
        {
            if(switchcaseflag)
            {
                switchcaseflag:=false
            }
            else
            {
                depth--  ; Case/Default：缩进减 1（与 Switch 同层级）
            }
        }
        else if (RegExMatch(purifiedLine, label) || RegExMatch(purifiedLine, hotkey) || RegExMatch(purifiedLine, hotkeySingleLine))
        {
            ; 标签后需缩进：标记深度等于当前深度时，缩进减 1
            if (indentCodeAfterLabel && tagDepth = depth)
            {
                depth--
            }
        }
        ; --------------------------
        ; 16. 边界处理：确保深度非负（避免异常缩进）
        ; --------------------------
        if (depth < 0)
        {
            depth := 0
        }
        if (preBlockCommentDepth < 0)
        {
            preBlockCommentDepth := 0
        }
        prevLineDepth := depth  ; 更新上一行深度，供下一行参考

        ; --------------------------
        ; 17. 输出当前行：添加缩进并拼接至结果字符串
        ; --------------------------
        formattedString .= buildIndentedLine(lineIndex, lines.length, formattedLine, depth, options)

        ; =====================================================================
        ; |                            下一行准备                            |
        ; =====================================================================

        ; --------------------------
        ; 1. 格式化指令处理：开启赋值对齐/块注释格式化（空行中的指令）
        ; --------------------------
        if (emptyLine)
        {
            ; 开启赋值对齐
            if ( ahkAlignAssignmentOn)
            {
                alignAssignment := true
            }
            ; 开启块注释格式化
            else if (ahkFormatBlockCommentOn)
            {
                formatBlockComment := true
            }
        }
        ; --------------------------
        ; 2. 单行控制流处理：重置状态并调整下一行缩进
        ; --------------------------
        if (oneCommandCode && (!blockComment || formatBlockComment))
        {
            oneCommandCode := false  ; 重置当前单行控制流状态
            prevLineIsOneCommandCode := true  ; 标记上一行是单行控制流
            ; 下一行非单行控制流：当前深度减 1（避免下一行多缩进）
            if (!nextLineIsOneCommandCode(purifiedLine))
            {
                depth--
            }
        }
        else
        {
            prevLineIsOneCommandCode := false  ; 重置上一行单行控制流标记
        }
        ; --------------------------
        ; 3. 控制流处理：无大括号时记录层级（单行控制流的下一行需缩进）
        ; --------------------------
        if (nextLineIsOneCommandCode(purifiedLine) && openBraceNum = 0 && focDepth.last() = -1)
        {
            focDepth.push(depth)  ; 记录当前深度到通用控制流管理器
        }
        ; --------------------------
        ; 4. 控制流处理：记录 if/else if 层级
        ; --------------------------
        if (RegExMatch(purifiedLine, "^(}? ?else )?if\b(?!:)"))
        {
            ifDepth.push(depth)  ; 记录当前深度到 if 控制流管理器
        }
        ; --------------------------
        ; 5. 代码块处理：进入代码块（左大括号 {，调整缩进和控制流状态）
        ; --------------------------
        if (openBraceNum)
        {
            depth += openBraceNum  ; 缩进随左大括号数量增加
            detectOneCommandCode := false  ; 关闭单行控制流检测（避免重复缩进）
            ; 非表达式续行：标记左大括号触发缩进
            if (!continuationSectionExpression)
            {
                openBraceIndent := true
            }
            else
            {
                openBraceIndent := false
            }
            ; 记录 if/通用控制流的代码块开始（添加分隔符）
            ifDepth.enterBlockOfCode(openBraceNum)
            focDepth.enterBlockOfCode(openBraceNum)
        }
        else
        {
            openBraceIndent := false  ; 无左大括号：重置左大括号缩进标记
        }
        ; --------------------------
        ; 6. 特殊指令处理：#If 指令后缩进（按配置开启）
        ; --------------------------
        if (RegExMatch(purifiedLine, "^" . sharpDirective . "\b.+") && indentCodeAfterIfDirective)
        {
            depth++  ; #If 后需缩进：深度加 1
            tagDepth := 0  ; 重置标记深度
        }
        ; --------------------------
        ; 7. 特殊语句处理：Switch-Case/Default 或 Label/Hotkey 后缩进
        ; --------------------------

        if (RegExMatch(purifiedLine, switchCaseDefault))
        {
            depth++  ; Case/Default 后：缩进加 1（Case 内代码缩进）
        }
        else if (RegExMatch(purifiedLine, label) || RegExMatch(purifiedLine, hotkey))
        {
            ; 标签后需缩进且通用控制流无嵌套：深度加 1，标记深度设为当前深度
            if (indentCodeAfterLabel && focDepth.depth.Length = 1)
            {
                depth++
                tagDepth := depth
            }
        }
        else if (RegExMatch(purifiedLine, hotkeySingleLine))
        {
            tagDepth := 0  ; 单行热键后：重置标记深度（避免后续语句异常缩进）
        }
        ; --------------------------
        ; 8. 续行处理：表达式续行结束（调整缩进）
        ; --------------------------
        if (continuationSectionExpression)
        {
            continuationSectionExpression := false  ; 重置表达式续行状态
            ; 有右大括号：深度随右大括号数量减少
            if (closeBraceNum)
            {
                depth -= closeBraceNum
                ; 右大括号后深度等于对象续行深度：重置对象深度标记，深度加 1
                if (openBraceObjectDepth = depth)
                {
                    openBraceObjectDepth := -1
                    depth++
                }
            }
            depth--  ; 表达式续行结束：深度减 1（回溯到续行前层级）
        }
        ; --------------------------
        ; 9. 续行处理：格式化文本续行开始（(LTrim 开头，调整缩进）
        ; --------------------------
        if (RegExMatch(purifiedLine, "^\((?!::)(?=.*\bltrim\b)"))
        {
            continuationSectionTextFormat := true
            depth++
        }
        ;单行控制流缩进
        if (detectOneCommandCode && nextLineIsOneCommandCode(purifiedLine))
        {
            oneCommandCode := true
            depth++
        }
        ; 调试输出（文件末尾检查控制流状态）
        if (lineIndex = lines.length - 1)
        {
        }
    }
    ;对齐单行注释
    formattedString := alignSingleLineComments(formattedString, options)

    ;清理空行
    formattedString := removeEmptyLines(formattedString,options.allowedNumberOfEmptyLines,)

    return formattedString
}
FormatAllmanStyle(strInput)
{
    output := ""
    inDoubleQuotes := false  ; 双引号字符串标记
    inSingleQuotes := false  ; 单引号字符串标记
    inLineComment := false   ; 单行注释标记（; 开头）
    inBlockComment := false  ; 块注释标记（/** ... */）
    strLength := StrLen(strInput)

    Loop strLength
    {
        currentChar := SubStr(strInput, A_Index, 1)
        nextChar := (A_Index < strLength) ? SubStr(strInput, A_Index + 1, 1) : ""

        ; 1. 处理块注释状态（/** 开头，*/ 结尾）
        if (!inBlockComment && !inDoubleQuotes && !inSingleQuotes && !inLineComment)
        {
            ; 检测块注释开始：当前是/且下一个是*且下下个是*
            if (currentChar = "/" && nextChar = "*" && SubStr(strInput, A_Index + 2, 1) = "*")
            {
                inBlockComment := true
                output .= currentChar  ; 添加第一个/
                continue  ; 后续字符在循环中处理
            }
        }
        ; 检测块注释结束：当前是*且下一个是/
        if (inBlockComment && currentChar = "*" && nextChar = "/")
        {
            inBlockComment := false
            output .= currentChar  ; 添加*
            continue  ; 下一个/会在循环中处理
        }
        ; 2. 处理单行注释状态（; 开头，换行结束）
        if (!inLineComment && !inDoubleQuotes && !inSingleQuotes && !inBlockComment)
        {
            if (currentChar = ";")
            {
                inLineComment := true
                output .= currentChar
                continue
            }
        }
        ; 单行注释换行后结束
        if (inLineComment && (currentChar = "`n" || currentChar = "`r"))
        {
            inLineComment := false
        }
        ; 3. 处理引号状态（优先于注释）
        if (currentChar = '"' && !inSingleQuotes && !inBlockComment && !inLineComment)
        {
            inDoubleQuotes := !inDoubleQuotes
            output .= currentChar
            continue
        }
        if (currentChar = "'" && !inDoubleQuotes && !inBlockComment && !inLineComment)
        {
            inSingleQuotes := !inSingleQuotes
            output .= currentChar
            continue
        }
        ; 4. 内容处理逻辑
        if (inDoubleQuotes || inSingleQuotes || inLineComment || inBlockComment)
        {
            ; 字符串或注释中的内容：直接添加，不处理大括号
            output .= currentChar
        }
        else
        {
            ; 代码中的大括号：添加换行
            if (currentChar = "{" || currentChar = "}")
            {
                output .= "`n" currentChar "`n"
            }
            else
            {
                output .= currentChar
            }
        }
    }
    output := CleanBracesEmptyLines(output)
    return output
}
; 辅助函数：移除大括号前后的所有空行
CleanBracesEmptyLines(docString)
{
    ; 统一换行符为\n
    docString := StrReplace(docString, "`r`n", "`n")

    ; 处理左大括号 { 前的空行：匹配{前的所有空行，替换为单个换行
    docString := RegExReplace(docString, "(?:\s*\n)+(?={)", "`n")
    ; 处理左大括号 { 后的空行：匹配{后的所有空行，替换为{+单个换行
    docString := RegExReplace(docString, "{(?:\n\s*)+", "{`n")

    ; 处理右大括号 } 前的空行：匹配}前的所有空行，替换为单个换行
    docString := RegExReplace(docString, "(?:\s*\n)+(?=})", "`n")
    ; 处理右大括号 } 后的空行：匹配}后的所有空行，替换为}+单个换行
    docString := RegExReplace(docString, "}(?:\n\s*)+", "}`n")

    ; 特殊处理：移除行首大括号前的多余换行
    docString := RegExReplace(docString, "^`n([{}])", "$1")

    ; 还原为Windows换行符
    return StrReplace(docString, "`n", "`r`n")
}
oSciTE:= ComObjActive("SciTE4AHK.Application")
; SciTE的 Hwnd
SciTEHwnd := oSciTE.SciTEHandle
; 编辑器的 Hwnd
EditHwnd := ControlGetHwnd("Scintilla1", "ahk_id" SciTEHwnd)
format()
{
    codetext:=oSciTE.Selection
    if(codetext="")
    {
        codetext:=oSciTE.Document
        fmtext:=internalFormat(codetext,options2)
        postion:=oSciTE.GetCurPos
        ; 清空编辑器文本
        ControlSetText("", "Scintilla1", "ahk_id " SciTEHwnd)
        oSciTE.InsertText(fmtext)
        oSciTE.SetCurPos(postion)
    }
    else
    {
        fmtext:=internalFormat(codetext,options2)
        ; 清空编辑器文本
        oSciTE.ReplaceSel(fmtext)
    }
}
format()

; text:=(internalFormat(A_Clipboard,options2))
; Print(text)

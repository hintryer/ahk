
const commentRegExp = /(?<=^|\s+);.*/; // 导入注释匹配正则（如匹配单行注释";"）
type FormattingOptions =  {
    insertSpaces: boolean;
    tabSize: number;
    indentCodeAfterLabel: boolean;
    indentCodeAfterIfDirective: boolean;
    preserveIndent: boolean;
    trimExtraSpaces: boolean;
    allowedNumberOfEmptyLines: number;
}; // 导入格式化配置选项类型定义


/**
 * 将文档对象转换为统一换行符（\n）的字符串
 * 处理 VS Code 文档对象的换行符差异（不同系统可能为\n或\r\n），统一输出为\n
 * @param document 文档对象，需包含 lineCount（行数）和 lineAt（获取指定行）方法
 * @returns 统一换行符的文档字符串
 */


/**
 * 生成指定深度的缩进字符
 * 根据 VS Code 用户配置（空格/制表符缩进）生成对应格式的缩进
 * @param depth 缩进深度（几级缩进）
 * @param options 格式化选项，包含 insertSpaces（是否用空格）和 tabSize（空格缩进时的字符数）
 * @returns 缩进字符字符串（如 depth=2、tabSize=4 时返回"    "）
 */
export function buildIndentationChars(
    depth: number,
    options: Pick<FormattingOptions, 'insertSpaces' | 'tabSize'>,
): string {
    return options.insertSpaces
        ? ' '.repeat(depth * options.tabSize) // 空格缩进：深度×每个缩进的空格数
        : '\t'.repeat(depth); // 制表符缩进：深度×制表符
}


/**
 * 生成带缩进的代码行（非最终保存版本，无换行符）
 * 处理空行的缩进保留逻辑，避免空行丢失缩进
 * @param indentationChars 缩进字符（由 buildIndentationChars 生成）
 * @param formattedLine 格式化后的行文本（无缩进）
 * @param preserveIndentOnEmptyString 空行是否保留缩进
 * @returns 带缩进的行文本（末尾无换行符）
 */
export function buildIndentedString(
    indentationChars: string,
    formattedLine: string,
    preserveIndentOnEmptyString: boolean,
): string {
    if (preserveIndentOnEmptyString) {
        // 保留空行缩进：即使行文本为空，也添加缩进
        return indentationChars + formattedLine;
    }
    // 不保留空行缩进：非空行添加缩进，空行返回原文本（无缩进）
    return !formattedLine?.trim()
        ? formattedLine
        : indentationChars + formattedLine;
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
export function buildIndentedLine(
    lineIndex: number,
    lastLineIndex: number,
    formattedLine: string,
    depth: number,
    options: Pick<FormattingOptions, 'insertSpaces' | 'tabSize' | 'preserveIndent'>,
): string {
    // 1. 生成当前深度的缩进字符
    const indentationChars = buildIndentationChars(depth, options);
    // 2. 生成带缩进的行文本（无换行符）
    let indentedLine = buildIndentedString(
        indentationChars,
        formattedLine,
        options.preserveIndent,
    );
    // 3. 非最后一行添加换行符（避免文档末尾多余空行）
    if (lineIndex !== lastLineIndex - 1) {
        indentedLine += '\n';
    }
    return indentedLine;
}


/**
 * 检查一行中右括号（()）是否比左括号多
 * 用于判断代码块是否提前闭合，辅助缩进计算
 * @param line 待检查的行文本
 * @returns 右括号数量 > 左括号数量时返回 true，否则 false
 */
export function hasMoreCloseParens(line: string): boolean {
    if (!line.includes(')')) return false; // 无右括号直接返回 false
    const openCount = line.match(/\(/g)?.length ?? 0; // 左括号数量（无匹配时为0）
    const closeCount = line.match(/\)/g)!.length;
    return closeCount > openCount;
}


/**
 * 检查一行中左括号（()）是否比右括号多
 * 用于判断代码块是否未闭合，辅助缩进计算
 * @param line 待检查的行文本
 * @returns 左括号数量 > 右括号数量时返回 true，否则 false
 */
export function hasMoreOpenParens(line: string): boolean {
    if (!line.includes('(')) return false; // 无左括号直接返回 false
    const openCount = line.match(/\(/g)!.length; // 左括号数量（已确认有左括号，无需判空）
    const closeCount = line.match(/\)/g)?.length ?? 0; // 右括号数量（无匹配时为0）
    return openCount > closeCount;
}


/**
 * 净化代码行：移除注释、字符串字面量、代码块等干扰内容，保留核心语法结构
 * 用于分析代码行的语法类型（如是否为控制流语句、赋值语句）
 * @param original 原始代码行
 * @returns 净化后的代码行（仅保留核心语法关键字）
 */
export function purify(original: string): string {
    if (!original) return ''; // 空行直接返回

    // AHK 内置命令列表（从 SciTE4AutoHotkey 工具提取，覆盖所有核心命令）
    // 用于区分「命令」和「函数调用」（命令后无括号，函数后有括号）
    const commandList = [
        'autotrim', 'blockinput', 'click', 'clipwait', 'control', 'controlclick',
        'controlfocus', 'controlget', 'controlgetfocus', 'controlgetpos', 'controlgettext',
        'controlmove', 'controlsend', 'controlsendraw', 'controlsettext', 'coordmode',
        'critical', 'detecthiddentext', 'detecthiddenwindows', 'drive', 'driveget',
        'drivespacefree', 'edit', 'envadd', 'envdiv', 'envget', 'envmult', 'envset',
        'envsub', 'envupdate', 'exit', 'exitapp', 'fileappend', 'filecopy', 'filecopydir',
        'filecreatedir', 'filecreateshortcut', 'filedelete', 'fileencoding', 'filegetattrib',
        'filegetshortcut', 'filegetsize', 'filegettime', 'filegetversion', 'fileinstall',
        'filemove', 'filemovedir', 'fileread', 'filereadline', 'filerecycle',
        'filerecycleempty', 'fileremovedir', 'fileselectfile', 'fileselectfolder',
        'filesetattrib', 'filesettime', 'formattime', 'getkeystate', 'groupactivate',
        'groupadd', 'groupclose', 'groupdeactivate', 'gui', 'guicontrol', 'guicontrolget',
        'hotkey', 'imagesearch', 'inidelete', 'iniread', 'iniwrite', 'input', 'inputbox',
        'keyhistory', 'keywait', 'listhotkeys', 'listlines', 'listvars', 'menu',
        'mouseclick', 'mouseclickdrag', 'mousegetpos', 'mousemove', 'msgbox', 'onexit',
        'outputdebug', 'pause', 'pixelgetcolor', 'pixelsearch', 'postmessage', 'process',
        'progress', 'random', 'regdelete', 'regread', 'regwrite', 'reload', 'run',
        'runas', 'runwait', 'send', 'sendevent', 'sendinput', 'sendlevel', 'sendmessage',
        'sendmode', 'sendplay', 'sendraw', 'setbatchlines', 'setcapslockstate',
        'setcontroldelay', 'setdefaultmousespeed', 'setenv', 'setformat', 'setkeydelay',
        'setmousedelay', 'setnumlockstate', 'setregview', 'setscrolllockstate',
        'setstorecapslockmode', 'settimer', 'settitlematchmode', 'setwindelay',
        'setworkingdir', 'shutdown', 'sleep', 'sort', 'soundbeep', 'soundget',
        'soundgetwavevolume', 'soundplay', 'soundset', 'soundsetwavevolume', 'splashimage',
        'splashtextoff', 'splashtexton', 'splitpath', 'statusbargettext', 'statusbarwait',
        'stringcasesense', 'stringgetpos', 'stringleft', 'stringlen', 'stringlower',
        'stringmid', 'stringreplace', 'stringright', 'stringsplit', 'stringtrimleft',
        'stringtrimright', 'stringupper', 'suspend', 'sysget', 'thread', 'tooltip',
        'transform', 'traytip', 'urldownloadtofile', 'winactivate', 'winactivatebottom',
        'winclose', 'winget', 'wingetactivestats', 'wingetactivetitle', 'wingetclass',
        'wingetpos', 'wingettext', 'wingettitle', 'winhide', 'winkill', 'winmaximize',
        'winmenuselectitem', 'winminimize', 'winminimizeall', 'winminimizeallundo',
        'winmove', 'winrestore', 'winset', 'winsettitle', 'winshow', 'winwait',
        'winwaitactive', 'winwaitclose', 'winwaitnotactive'
    ];

    let cmdTrim = original; // 临时变量，用于提取命令关键字

    // 遍历命令列表，匹配行中的命令（命令后无括号，函数后有括号）
    // 例如："ControlSend, Control, Keys" → 提取为"ControlSend"；"ControlSend()" → 保留为函数调用
    for (const command of commandList) {
        const pattern =
            '(' +                    // 捕获组1：匹配命令关键字
            '^\\s*' +                // 行首可选空白（缩进）
            command +                // 命令关键字（如ControlSend）
            '\\b' +                  // 单词边界（避免匹配命令的子串，如"Control"匹配"ControlSend"）
            '(?!\\()' +              // 负向预查：命令后不能跟"("（排除函数调用）
            ')' +                    // 捕获组结束
            '.*';                    // 命令后的所有内容（需删除）
        const regExp = new RegExp(pattern, 'i'); // 不区分大小写（AHK命令大小写不敏感）

        if (original.search(regExp) !== -1) {
            cmdTrim = original.replace(regExp, '$1'); // 保留命令关键字，删除后续内容
            break; // 匹配到一个命令即可，避免重复处理
        }
    }

    // 进一步净化：移除字符串字面量、代码块、多余空格和注释
    let pure = cmdTrim
        .replace(/".*?"/g, '""') // 替换字符串字面量为空字符串（如"abc"→""），避免干扰语法分析
        .replaceAll(/{[^{}]*}/g, '') // 移除匹配的代码块（如{...}），避免大括号干扰
        .replace(/\s+/g, ' ') // 合并多个空白为单个空格（统一空格格式）
        .replace(commentRegExp, '') // 移除注释（必须最后执行，避免误删字符串中的";"）
        .trim(); // 去除首尾空白

    return pure;
}


/**
 * 判断当前行是否为「单行控制流语句」（下一行需缩进）
 * 单行控制流语句指 if/loop/while 等无大括号的语句，下一行代码需缩进
 * 例：if (var) → 下一行 MsgBox 需缩进
 * @param text 净化后的当前行文本（由 purify 生成）
 * @returns 是单行控制流语句则返回 true，否则 false
 */
export function nextLineIsOneCommandCode(text: string): boolean {
    // 需触发下一行缩进的控制流关键字列表
    const oneCommandList = [
        'ifexist', 'ifinstring', 'ifmsgbox', 'ifnotexist', 'ifnotinstring',
        'ifwinactive', 'ifwinexist', 'ifwinnotactive', 'ifwinnotexist',
        'if', 'else', 'loop', 'for', 'while', 'catch'
    ];

    // 遍历关键字列表，匹配当前行是否为单行控制流语句
    for (const oneCommand of oneCommandList) {
        // 匹配规则：
        // 1. 行首可选 "}"（如"} else"场景）
        // 2. 关键字（如if），且后接单词边界（避免匹配子串）
        // 3. 关键字后不能跟":"（排除标签，如"If:"是标签而非控制流）
        if (text.match('^}?\\s*' + oneCommand + '\\b(?!:)')) {
            return true;
        }
    }
    return false;
}


/**
 * 清理文档中的空行：移除开头空行 + 限制连续空行数量
 * 按用户配置保留指定数量的连续空行，避免空行过多或过少
 * @param docString 待处理的文档字符串
 * @param allowedNumberOfEmptyLines 允许的最大连续空行数量（-1 表示不限制）
 * @returns 清理空行后的文档字符串
 */
export function removeEmptyLines(
    docString: string,
    allowedNumberOfEmptyLines: number,
): string {
    if (allowedNumberOfEmptyLines === -1) {
        return docString; // 不限制空行，直接返回原字符串
    }

    // 正则：匹配「1个换行符 + N个（空白+换行符）」（N ≥ 允许的空行数量）
    // \s*?：非贪婪匹配空白（避免匹配换行符外的其他空白）
    const emptyLines = new RegExp(
        `\\n(\\s*?\\n){${allowedNumberOfEmptyLines},}`,
        'g'
    );

    return docString
        .replace(emptyLines, '\n' + '$1'.repeat(allowedNumberOfEmptyLines)) // 替换多余空行为允许数量
        .replace(/^\s*\n+/, ''); // 移除文档开头的所有空行
}


/**
 * 清理行中的多余空格（仅保留单词间单个空格）
 * 按用户配置决定是否清理，避免代码中空格混乱
 * @param line 待处理的行文本
 * @param trimExtraSpaces 是否清理多余空格（用户配置）
 * @returns 清理空格后的行文本
 */
export function trimExtraSpaces(
    line: string,
    trimExtraSpaces: boolean,
): string {
    return trimExtraSpaces
        ? line.replace(/ {2,}/g, ' ') // 清理：多个空格→单个空格
        : line; // 不清理，返回原文本
}


/**
 * 计算一行中未匹配的大括号数量（{ 或 }）
 * 先移除嵌套的代码块，再统计目标大括号数量，避免嵌套干扰
 * @param line 待处理的行文本
 * @param braceChar 目标大括号（{ 或 }）
 * @returns 未匹配的目标大括号数量
 */
export function braceNumber(line: string, braceChar: '{' | '}'): number {
    const braceRegEx = new RegExp(braceChar, 'g'); // 匹配目标大括号的正则
    // 1. 移除所有嵌套代码块（{...}），避免内部大括号干扰
    // 2. 统计剩余文本中的目标大括号数量（无匹配时为0）
    const braceNum = replaceAll(line, /{[^{}]*}/g, '').match(braceRegEx)?.length ?? 0;
    return braceNum;
}

/**
 * 【赋值语句等号对齐主函数】
 * 将多行赋值语句的 `=` 或 `:=` 运算符对齐到同一列，确保代码视觉一致性
 * @param text 待对齐的赋值语句数组（每行一个赋值语句）
 * @returns 等号对齐后的赋值语句数组
 */
export function alignTextAssignOperator(text: string[]): string[] {
    /** 
     * 步骤1：计算所有赋值语句中「第一个等号」的最右侧位置
     * - 先通过 `normalizeLineAssignOperator` 标准化每行格式（清理注释、统一空格）
     * - 再获取标准化后每行等号的索引，取最大值作为「目标对齐位置」
     */
    const maxPosition = Math.max(
        ...text.map((line) => normalizeLineAssignOperator(line).indexOf('=')),
    );

    /** 
     * 步骤2：按最右侧位置对齐所有等号
     * - 调用 `alignLineAssignOperator` 为每行补充空格，使等号统一移动到 `maxPosition`
     */
    const alignedText = text.map((line) =>
        alignLineAssignOperator(line, maxPosition),
    );
    return alignedText;
}

/**
 * 【赋值语句标准化】
 * 清理赋值语句中的干扰内容，统一等号前后格式，为等号对齐做前置准备
 * 核心目标：确保每行赋值语句的等号格式一致，避免注释、多余空格影响对齐计算
 * @param original 原始赋值语句行（可能含注释、等号前后空格不统一、单词间多余空格）
 * @returns 标准化后的语句（无注释、等号前后各1个空格、单词间仅1个空格）
 */
export function normalizeLineAssignOperator(original: string): string {
    return (
        original 
            // 1. 移除单行注释：跳过转义的分号 `;`（如字符串中的 `a`;b`，避免误删内容）
            .replace(/(?<!`);.+/, '') 
            // 2. 清理单词间多余空格：保留行首缩进（影响代码层级）和行尾空格（影响注释对齐）
            //    仅将「非行首/行尾的连续2个以上空格」替换为1个空格
            .replace(/(?<=\S) {2,}(?=\S)/g, ' ')
            // 3. 统一等号前空格：无论原是否有空格，均确保等号（含 `:=`）前有1个空格
            .replace(/\s?(?=:?=)/, ' ')
            // 4. 统一等号后空格：无论原是否有空格，均确保等号（含 `:=`）后有1个空格
            .replace(/(?<=:?=)\s?/, ' ')
    );
}

/**
 * 【单行赋值等号对齐】
 * 根据目标位置为单行赋值语句补充空格，使等号对齐，并恢复原注释（避免丢失注释）
 * @param original 原始赋值语句行（含注释）
 * @param targetPosition 等号的目标对齐位置（所有行的最右等号索引）
 * @returns 等号对齐后的完整语句（含原注释、无行尾多余空格）
 */
export function alignLineAssignOperator(
    original: string,
    targetPosition: number,
): string {
    /** 步骤1：提取并保存行尾注释（后续需恢复，避免对齐过程中丢失） */
    const comment = /;.+/.exec(original)?.[0] ?? ''; 
    /** 步骤2：标准化原始行（清理注释、统一等号格式，便于计算空格数量） */
    original = normalizeLineAssignOperator(original);
    /** 步骤3：获取当前行等号的原始位置（用于计算需补充的空格数） */
    const position = original.indexOf('='); 

    return original
        // 4. 补充空格使等号移动到目标位置：用「目标位置 - 原始位置 + 1」个空格替换等号前的1个空格
        .replace(/\s(?=:?=)/, ' '.repeat(targetPosition - position + 1))
        // 5. 恢复之前提取的行尾注释（确保注释不丢失）
        .concat(comment)
        // 6. 去除行尾多余空格（避免格式混乱，保持代码整洁）
        .trimEnd();
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
export function replaceAll(
    text: string,
    search: RegExp,
    replace: string,
): string {
    while (true) {
        const len = text.length; // 记录替换前文本长度（用于判断是否有新替换）
        text = text.replace(search, replace); // 执行一次替换
        // 若替换前后长度相同（无新匹配或替换内容长度一致），退出循环
        if (text.length === len) {
            break;
        }
    }
    return text;
}

/**
 * 【控制流嵌套深度管理器】
 * 跟踪 if/loop/while 等控制流语句的缩进层级，处理嵌套代码块的缩进计算
 * 核心数据结构：用数组记录层级，`-1` 作为代码块分隔符（对应 `{}`），数字表示缩进深度
 * 作用：解决嵌套控制流的缩进回溯问题（如多层 if-else 后正确恢复缩进）
 */
export class FlowOfControlNestDepth {
    /** 
     * 层级数组：
     * - 元素为 `-1`：代码块分隔符（标记 `{` 的位置，用于识别代码块边界）
     * - 元素为数字：控制流语句的缩进深度（如 if 语句所在的层级）
     * - 初始值 `[-1]`：确保数组始终非空，避免索引越界异常
     */
    depth: number[];

    /**
     * 构造函数：初始化层级数组（支持传入已有数组恢复历史状态，如块注释退出后恢复控制流）
     * @param array 可选初始数组（用于恢复之前的控制流层级，避免状态丢失）
     */
    constructor(array?: number[]) {
        this.depth = array ?? [-1];
    }

    /**
     * 【进入代码块】
     * 对应代码中出现 `{` 时，添加分隔符标记代码块边界（每個 `{` 对应一个 `-1`）
     * @param openBraceNum 左大括号 `{` 的数量（即进入的代码块数量，支持多层嵌套）
     * @return 更新后的层级数组
     */
    enterBlockOfCode(openBraceNum: number) {
        for (let i = openBraceNum; i > 0; i--) {
            this.depth.push(-1); // 为每个 `{` 添加分隔符
        }
        return this.depth;
    }

    /**
     * 【退出代码块】
     * 对应代码中出现 `}` 时，回溯到上一层代码块边界（删除当前块的层级记录）
     * 示例：`[-1, 0, -1, 1, 2]`（两层嵌套）→ 退出1个代码块后 → `[-1, 0]`
     * @param closeBraceNum 右大括号 `}` 的数量（即退出的代码块数量，支持多层退出）
     * @return 更新后的层级数组
     */
    exitBlockOfCode(closeBraceNum: number) {
        for (let i = closeBraceNum; i > 0; i--) {
            // 找到最后一个分隔符 `-1` 的位置，删除其之后的所有元素（当前块的层级）
            this.depth.splice(this.depth.lastIndexOf(-1));
        }
        // 异常处理：若数组被清空（如多余 `}` 导致），恢复初始状态 `[-1]`
        this.restoreEmptyDepth();
        return this.depth;
    }

    /**
     * 【获取当前最内层层级】
     * 返回层级数组的最后一个元素（当前最内层的分隔符或缩进深度）
     * @returns 最后一个元素（数字表示缩进深度，`-1` 表示分隔符）
     */
    last() {
        return this.depth[this.depth.length - 1];
    }

    /**
     * 【添加层级记录】
     * 向层级数组添加一个控制流语句的缩进深度（如记录 if 语句的层级）
     * @param items 要添加的层级值（数字）
     * @return 添加后的数组长度（便于后续状态判断）
     */
    push(items: number) {
        return this.depth.push(items);
    }

    /**
     * 【移除最内层记录】
     * 从层级数组移除最后一个元素（回溯层级，如 else 对应 if 的层级删除）
     * @return 被移除的元素（数字或 `-1`）
     */
    pop() {
        const result = this.depth.pop();
        // 移除后若数组为空，恢复初始状态（避免后续操作异常）
        this.restoreEmptyDepth();
        return result;
    }

    /**
     * 【恢复当前代码块层级】
     * 删除分隔符后的多余层级，回溯到当前代码块的正确层级（用于控制流嵌套结束后）
     * 示例：`[-1, 0, -1, 1, 2]` → 恢复后 → `[-1, 0, -1]`，返回被移除的第一个层级 `1`
     * @return 恢复前分隔符后的第一个层级值（用于判断缩进回溯目标）
     */
    restoreDepth() {
        // 找到最后一个分隔符 `-1` 的位置，其下一个元素即为当前块的初始层级
        const index = this.depth.lastIndexOf(-1) + 1;
        const element = this.depth[index];
        // 删除分隔符后的所有元素（清理当前块的嵌套层级）
        this.depth.splice(index);
        return element;
    }

    /**
     * 【恢复空数组初始状态】
     * 若层级数组被清空（如异常的多 `}`），重置为初始值 `[-1]`，避免后续操作报错
     */
    restoreEmptyDepth() {
        if (this.depth.length === 0) {
            this.depth = [-1];
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
export function alignSingleLineComments(
    stringToFormat: string,
    options: Pick<FormattingOptions, 'insertSpaces' | 'tabSize' | 'preserveIndent'>,
): string {
    let depth = 0; // 当前代码行的缩进深度（用于记录上一行代码层级）
    let prevLineDepth = 0; // 上一行非空代码的缩进深度（用于对齐空行后的注释）
    const lines = stringToFormat.split('\n'); // 按行分割文档，逐行处理

    // 从后向前遍历：确保上一行代码的深度已计算（避免向前遍历漏算上一行）
    for (let i = lines.length - 1; i >= 0; i--) {
        const line = lines[i];
        /** 判断当前行是否为空行或纯注释行（净化后无代码内容即为空行/纯注释） */
        const emptyLine = purify(line) === '';

        if (emptyLine) {
            // 空行/纯注释行：使用上一行代码的深度对齐缩进
            const indentationChars = buildIndentationChars(prevLineDepth, options);
            lines[i] = buildIndentedString(
                indentationChars,
                line.trim(), // 清理原缩进，按计算的缩进重新对齐
                options.preserveIndent,
            );
        } else {
            // 非空代码行：计算当前行的缩进深度，并更新上一行代码深度
            depth = calculateDepth(line, options);
            // 特殊处理：若当前行是 `}`，需增加深度（避免注释在 `}` 后缩进不足）
            if (line.match(/^\s*}/)) {
                const braceNum = braceNumber(purify(line), '}');
                depth += braceNum;
            }
            prevLineDepth = depth; // 更新上一行代码深度，供后续注释使用
        }
    }

    return lines.join('\n'); // 重新拼接行，返回处理后的字符串
}

/**
 * 【计算代码行缩进深度】
 * 将代码行的缩进字符（空格/制表符）转换为层级（数字），统一缩进计算标准
 * @param text 待计算的代码行
 * @param options VS Code 格式化选项（含缩进类型：空格/制表符，缩进大小）
 * @return 缩进深度（数字，如 2 表示 2 级缩进）
 */
export function calculateDepth(
    text: string,
    options: Pick<FormattingOptions, 'insertSpaces' | 'tabSize'>,
): number {
    // 匹配行首的所有空白字符（空格或制表符）
    const indentationChars = text.match(/^\s+/);
    // 计算空白字符的总长度（无缩进时为 0）
    const charsNum = indentationChars?.[0].length ?? 0;

    // 按配置转换为缩进深度：
    // - 空格缩进：总长度 ÷ 每个缩进的空格数（如 4 空格/级 → 8 空格 = 2 级）
    // - 制表符缩进：总长度 = 缩进深度（1 制表符 = 1 级）
    return options.insertSpaces
        ? charsNum / options.tabSize
        : charsNum;
}

/**
 * 【核心格式化函数】
 * 整合所有格式化逻辑，处理整个 AHK 文档，是格式化工具的入口
 * 覆盖功能：缩进管理、控制流嵌套、赋值对齐、注释对齐、续行处理、空行清理等
 * @param stringToFormat 待格式化的文档字符串（完整 AHK 脚本）
 * @param options 完整的格式化配置选项（含缩进、对齐、空行等所有配置）
 * @return 完全格式化后的文档字符串
 */
export const internalFormat = (
    stringToFormat: string,
    options: FormattingOptions,
): string => {
    let formattedString = ''; // 最终格式化后的字符串，逐步拼接生成

    // ==============================
    // 1. 缩进相关状态变量（管理代码层级）
    // ==============================
    let depth = 0; // 当前行的缩进深度（初始为 0，无缩进）
    let prevLineDepth = 0; // 上一行的缩进深度（用于对齐和回溯）
    /**
     * 标记深度（tagDepth）：控制特殊语句（Return/Exit/Label/Hotkey）的缩进规则
     * - tagDepth = 0：特殊语句（Return/Exit）可取消缩进（如标签后）
     * - tagDepth = currentDepth：标签后代码需缩进，特殊语句可取消缩进（恢复到标签层级）
     * - tagDepth ≠ currentDepth：特殊语句不可取消缩进（如函数内的 Return）
     * - tagDepth > 0：#If 指令可按 tagDepth 跳转多层缩进
     */
    let tagDepth = 0;

    // ==============================
    // 2. 控制流相关状态变量（处理 if/loop/while 等嵌套）
    // ==============================
    let oneCommandCode = false; // 当前行是否为「单行控制流」（下一行需缩进，如 if 后无 {）
    let prevLineIsOneCommandCode = false; // 上一行是否为「单行控制流」（用于续行处理）
    /**
     * 是否检测单行控制流（detectOneCommandCode）：
     * 避免大括号 `{` 后重复缩进（如 if { 后无需再按单行控制流缩进）
     */
    let detectOneCommandCode = true;
    let ifDepth = new FlowOfControlNestDepth(); // if-else 嵌套深度管理器（单独管理，避免与其他控制流混淆）
    let focDepth = new FlowOfControlNestDepth(); // 通用控制流（loop/while/for 等）深度管理器

    // ==============================
    // 3. 赋值对齐相关状态变量
    // ==============================
    let alignAssignment = false; // 是否启用赋值对齐（由格式化指令 `;@AHK++AlignAssignmentOn` 控制）
    let assignmentBlock: string[] = []; // 存储待对齐的赋值语句块（多行赋值）

    // ==============================
    // 4. 续行相关状态变量
    // ==============================
    let continuationSectionExpression = false; // 是否处于「表达式续行」（如对象、条件表达式换行）
    let continuationSectionTextFormat = false; // 是否处于「格式化文本续行」（(LTrim 开头的文本块）
    let continuationSectionTextNotFormat = false; // 是否处于「原始文本续行」（无 LTrim，保留用户格式）
    let openBraceIndent = false; // 左大括号是否触发了缩进（用于对象续行回溯）
    let deferredOneCommandCode = false; // 延迟的单行控制流（续行后恢复缩进）
    let openBraceObjectDepth = -1; // 对象续行中左大括号的缩进深度（用于回溯）

    // ==============================
    // 5. 块注释相关状态变量
    // ==============================
    let blockComment = false; // 是否处于块注释中（/* ... */）
    let blockCommentIndent = ''; // 块注释的基础缩进（保留原注释缩进结构）
    let formatBlockComment = false; // 是否格式化块注释内容（由指令控制）
    // 块注释前的状态备份（退出块注释时恢复）
    let preBlockCommentDepth = 0;
    let preBlockCommentTagDepth = 0;
    let preBlockCommentPrevLineDepth = 0;
    let preBlockCommentOneCommandCode = false;
    let preBlockCommentIfDepth = new FlowOfControlNestDepth();
    let preBlockCommentFocDepth = new FlowOfControlNestDepth();

    // ==============================
    // 6. 配置别名（简化代码）
    // ==============================
    const indentCodeAfterLabel = options.indentCodeAfterLabel; // 标签后是否缩进
    const indentCodeAfterIfDirective = options.indentCodeAfterIfDirective; // #If 指令后是否缩进
    const trimSpaces = options.trimExtraSpaces; // 是否清理多余空格

    // ==============================
    // 7. 正则表达式（复用避免重复创建）
    // ==============================
    const ahkAlignAssignmentOn = /;\s*@AHK\+\+AlignAssignmentOn/i; // 赋值对齐开启指令
    const ahkAlignAssignmentOff = /;\s*@AHK\+\+AlignAssignmentOff/i; // 赋值对齐关闭指令
    const ahkFormatBlockCommentOn = /;\s*@AHK\+\+FormatBlockCommentOn/i; // 块注释格式化开启指令
    const ahkFormatBlockCommentOff = /;\s*@AHK\+\+FormatBlockCommentOff/i; // 块注释格式化关闭指令
    // 续行匹配：以 and/or/逗号/运算符等开头的行（需与上一行合并）
    const continuationSection =
        /^(((and|or|not)\b)|[\^!~?:&<>=.,|]|\+(?!\+)|-(?!-)|\/(?!\*)|\*(?!\/))/;
    const label = /^[^\s\t,`]+(?<!:):$/; // 标签匹配（如 Label:）
    const hotkey = /^.+::$/; // 热键/热字符串匹配（无代码，如 F1::）
    const hotkeySingleLine = /^.+::/; // 单行热键匹配（含代码，如 F1::Run Notepad）
    const sharpDirective =
        '#(ifwinactive|ifwinnotactive|ifwinexist|ifwinnotexist|if)'; // #If 指令匹配
    const switchCaseDefault = /^(case\s*.+?:|default:)\s*.*/; // Switch 的 Case/Default 匹配

    // 将文档按行拆分，准备逐行处理
    const lines = stringToFormat.split('\n');

    // 遍历每一行进行格式化
    lines.forEach((originalLine, lineIndex) => {
        const purifiedLine = purify(originalLine).toLowerCase(); // 净化行（去注释、去多余空格）
        const comment = commentRegExp.exec(originalLine)?.[0] ?? ''; // 提取注释
        let formattedLine = originalLine.replace(commentRegExp, ''); // 移除注释
        formattedLine = trimExtraSpaces(formattedLine, trimSpaces) // 清理多余空格
            .concat(comment) // 恢复注释
            .trim();
        const emptyLine = purifiedLine === ''; // 判断是否为空行或纯注释行

        detectOneCommandCode = true; // 默认开启单行控制流检测

        const openBraceNum = braceNumber(purifiedLine, '{'); // 统计本行左大括号数量
        const closeBraceNum = braceNumber(purifiedLine, '}'); // 统计本行右大括号数量

        // =====================================================================
        // |                            本行处理                              |
        // =====================================================================

        // 如果是空行，检测是否有格式化指令
        if (emptyLine) {
            if (alignAssignment && comment.match(ahkAlignAssignmentOff)) {
                alignAssignment = false;
                // 对齐当前收集的赋值块
                assignmentBlock = alignTextAssignOperator(assignmentBlock);
                assignmentBlock.forEach((alignedFormattedLine, index) => {
                    formattedString += buildIndentedLine(
                        lineIndex - assignmentBlock.length + index + 1,
                        lines.length,
                        alignedFormattedLine,
                        depth,
                        options,
                    );
                });
                assignmentBlock = [];
            }
            if (formatBlockComment && comment.match(ahkFormatBlockCommentOff)) {
                formatBlockComment = false;
            }
        }

        // 如果启用了赋值对齐，收集赋值行
        if (alignAssignment) {
            assignmentBlock.push(formattedLine);
            if (lineIndex !== lines.length - 1) {
                return; // 继续收集，不输出
            }
            // 如果到文件末尾还没遇到关闭指令，对齐剩余的赋值块
            assignmentBlock.forEach((alignedFormattedLine, index) => {
                formattedString += buildIndentedLine(
                    lineIndex - assignmentBlock.length + index + 1,
                    lines.length,
                    alignedFormattedLine,
                    depth,
                    options,
                );
            });
            assignmentBlock = [];
        }

        // 块注释开始处理
        if (!blockComment && originalLine.match(/^\s*\/\*/)) {
            blockComment = true;
            blockCommentIndent = originalLine.match(/(^\s*)\/\*/)?.[1] || '';
            if (formatBlockComment) {
                // 保存进入块注释前的状态
                preBlockCommentDepth = depth;
                preBlockCommentTagDepth = tagDepth;
                preBlockCommentPrevLineDepth = prevLineDepth;
                preBlockCommentOneCommandCode = oneCommandCode;
                preBlockCommentIfDepth = ifDepth;
                preBlockCommentFocDepth = focDepth;
                // 重置块注释内的缩进状态
                tagDepth = depth;
                prevLineDepth = depth;
                oneCommandCode = false;
                ifDepth = new FlowOfControlNestDepth();
                focDepth = new FlowOfControlNestDepth();
            }
        }

        // 块注释内容处理
        if (blockComment) {
            if (!formatBlockComment) {
                let blockCommentLine = '';
                if (originalLine.startsWith(blockCommentIndent)) {
                    blockCommentLine = originalLine.substring(blockCommentIndent.length);
                } else {
                    blockCommentLine = originalLine;
                }
                formattedString += buildIndentedLine(
                    lineIndex,
                    lines.length,
                    blockCommentLine.trimEnd(),
                    depth,
                    options,
                );
            }
            if (originalLine.match(/^\s*\*\//)) {
                blockComment = false;
                if (formatBlockComment) {
                    // 恢复块注释前的状态
                    depth = preBlockCommentDepth;
                    tagDepth = preBlockCommentTagDepth;
                    prevLineDepth = preBlockCommentPrevLineDepth;
                    oneCommandCode = preBlockCommentOneCommandCode;
                    ifDepth = preBlockCommentIfDepth;
                    focDepth = preBlockCommentFocDepth;
                }
            }
            if (!formatBlockComment) {
                return;
            }
        }

        // 处理单行注释（非格式化指令）
        if (
            emptyLine &&
            !comment.match(ahkAlignAssignmentOn) &&
            !comment.match(ahkAlignAssignmentOff) &&
            !comment.match(ahkFormatBlockCommentOn) &&
            !comment.match(ahkFormatBlockCommentOff)
        ) {
            formattedString += buildIndentedLine(
                lineIndex,
                lines.length,
                formattedLine,
                0,
                options,
            );
            return;
        }

        // 原始文本续行开始
        if (purifiedLine.match(/^\((?!::)(?!.*\bltrim\b)/)) {
            continuationSectionTextNotFormat = true;
        }

        // 原始文本续行内容（保留用户格式）
        if (continuationSectionTextNotFormat) {
            formattedString += originalLine.trimEnd() + '\n';
            if (purifiedLine.match(/^\)/)) {
                continuationSectionTextNotFormat = false;
            }
            return;
        }

        // 格式化文本续行结束
        if (continuationSectionTextFormat && purifiedLine.match(/^\)/)) {
            continuationSectionTextFormat = false;
            depth--;
        }

        // 格式化文本续行内容（按缩进格式化）
        if (continuationSectionTextFormat) {
            formattedString += buildIndentedLine(
                lineIndex,
                lines.length,
                originalLine.trim(),
                depth,
                options,
            );
            return;
        }

        // 表达式/对象续行处理
        if (
            purifiedLine.match(continuationSection) &&
            !purifiedLine.match(/::/)
        ) {
            continuationSectionExpression = true;
            if (openBraceIndent) {
                depth--;
                openBraceObjectDepth = prevLineDepth;
            }
            if (oneCommandCode) {
                deferredOneCommandCode = true;
                oneCommandCode = false;
                prevLineIsOneCommandCode = false;
                depth--;
            }
            if (prevLineIsOneCommandCode) {
                oneCommandCode = true;
                depth++;
            }
            depth++;
        }

        // 恢复延迟的单行控制流缩进
        if (deferredOneCommandCode && !continuationSectionExpression) {
            deferredOneCommandCode = false;
            oneCommandCode = true;
            depth++;
        }

        // 处理右大括号（退出代码块）
        if (closeBraceNum) {
            if (focDepth.last() > -1) {
                depth = focDepth.last();
            }
            ifDepth.exitBlockOfCode(closeBraceNum);
            focDepth.exitBlockOfCode(closeBraceNum);
            if (!continuationSectionExpression) {
                depth -= closeBraceNum;
            }
        }

        // 处理左大括号（进入代码块）
        if (openBraceNum) {
            if (
                (oneCommandCode || deferredOneCommandCode) &&
                !nextLineIsOneCommandCode(purifiedLine)
            ) {
                if (deferredOneCommandCode) {
                    deferredOneCommandCode = false;
                } else if (purifiedLine.match(/^{/)) {
                    oneCommandCode = false;
                    depth -= openBraceNum;
                }
                if (depth === focDepth.last()) {
                    focDepth.pop();
                }
            }
        }

        // 控制流退出嵌套（非续行、非单行控制流、非块注释）
        if (
            (ifDepth.last() > -1 || focDepth.last() > -1) &&
            !continuationSectionExpression &&
            !oneCommandCode &&
            (!blockComment || formatBlockComment)
        ) {
            if (purifiedLine.match(/^}? ?else\b(?!:)/)) {
                depth = ifDepth.pop()!;
            } else if (!purifiedLine.match(/^{/) && !purifiedLine.match(/^}/)) {
                const restoreIfDepth = ifDepth.restoreDepth();
                const restoreFocDepth = focDepth.restoreDepth();
                if (
                    restoreIfDepth !== undefined &&
                    restoreFocDepth !== undefined
                ) {
                    depth = Math.min(restoreIfDepth, restoreFocDepth);
                } else {
                    depth = restoreIfDepth ?? restoreFocDepth;
                }
            }
        }

        // 处理 #If 指令
        if (purifiedLine.match('^' + sharpDirective + '\\b')) {
            if (tagDepth > 0) {
                depth -= tagDepth;
            } else {
                depth--;
            }
        }

        // 处理 Return/Exit/ExitApp（强制退回到标签层级）
        if (
            purifiedLine.match(/^(return|exit|exitapp)\b/) &&
            tagDepth === depth
        ) {
            tagDepth = 0;
            depth--;
        }

        // 处理 Switch-Case/Default 或 Label/Hotkey
        if (purifiedLine.match(switchCaseDefault)) {
            depth--;
        } else if (
            purifiedLine.match(label) ||
            purifiedLine.match(hotkey) ||
            purifiedLine.match(hotkeySingleLine)
        ) {
            if (indentCodeAfterLabel) {
                if (tagDepth === depth) {
                    depth--;
                }
            }
        }

        // 确保深度不为负
        if (depth < 0) depth = 0;
        if (preBlockCommentDepth < 0) preBlockCommentDepth = 0;

        prevLineDepth = depth;

        // 保存当前行（已缩进）
        formattedString += buildIndentedLine(
            lineIndex,
            lines.length,
            formattedLine,
            depth,
            options,
        );

        // =====================================================================
        // |                            下一行准备                            |
        // =====================================================================

        // 检测格式化指令（开启）
        if (emptyLine) {
            if (comment.match(ahkAlignAssignmentOn)) {
                alignAssignment = true;
            } else if (comment.match(ahkFormatBlockCommentOn)) {
                formatBlockComment = true;
            }
        }

        // 单行控制流处理
        if (
            oneCommandCode &&
            (!blockComment || formatBlockComment)
        ) {
            oneCommandCode = false;
            prevLineIsOneCommandCode = true;
            if (!nextLineIsOneCommandCode(purifiedLine)) {
                depth--;
            }
        } else {
            prevLineIsOneCommandCode = false;
        }

        // 控制流无大括号时记录层级
        if (
            nextLineIsOneCommandCode(purifiedLine) &&
            openBraceNum === 0 &&
            focDepth.last() === -1
        ) {
            focDepth.push(depth);
        }

        // 处理 if/else if
        if (purifiedLine.match(/^(}? ?else )?if\b(?!:)/)) {
            ifDepth.push(depth);
        }

        // 处理左大括号缩进
        if (openBraceNum) {
            depth += openBraceNum;
            detectOneCommandCode = false;
            if (!continuationSectionExpression) {
                openBraceIndent = true;
            } else {
                openBraceIndent = false;
            }
            ifDepth.enterBlockOfCode(openBraceNum);
            focDepth.enterBlockOfCode(openBraceNum);
        } else {
            openBraceIndent = false;
        }

        // #If 指令后缩进
        if (
            purifiedLine.match('^' + sharpDirective + '\\b.+') &&
            indentCodeAfterIfDirective
        ) {
            depth++;
            tagDepth = 0;
        }

        // Switch-Case/Default 或 Label/Hotkey 后缩进
        if (purifiedLine.match(switchCaseDefault)) {
            depth++;
        } else if (purifiedLine.match(label) || purifiedLine.match(hotkey)) {
            if (indentCodeAfterLabel) {
                if (focDepth.depth.length === 1) {
                    depth++;
                    tagDepth = depth;
                }
            }
        } else if (purifiedLine.match(hotkeySingleLine)) {
            tagDepth = 0;
        }

        // 续行后处理
        if (continuationSectionExpression) {
            continuationSectionExpression = false;
            if (closeBraceNum) {
                depth -= closeBraceNum;
                if (openBraceObjectDepth === depth) {
                    openBraceObjectDepth = -1;
                    depth++;
                }
            }
            depth--;
        }

        // 格式化文本续行开始
        if (purifiedLine.match(/^\((?!::)(?=.*\bltrim\b)/)) {
            continuationSectionTextFormat = true;
            depth++;
        }

        // 单行控制流缩进
        if (detectOneCommandCode && nextLineIsOneCommandCode(purifiedLine)) {
            oneCommandCode = true;
            depth++;
        }

        // 调试输出（文件末尾检查控制流状态）
        if (lineIndex === lines.length - 1) {
        
        }
    });

    // 对齐单行注释
    formattedString = alignSingleLineComments(formattedString, options);

    // 清理空行
    formattedString = removeEmptyLines(
        formattedString,
        options.allowedNumberOfEmptyLines,
    );

    return formattedString;
};
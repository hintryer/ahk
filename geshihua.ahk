#Include <print>
#SingleInstance force
; 将不在双引号对中的大括号前后添加换行
AddNewlinesToBraces(strInput) {
    output := ""
    inQuotes := false  ; 标记是否在双引号对中
    strLength := StrLen(strInput)
    
    Loop strLength {
        currentChar := SubStr(strInput, A_Index, 1)
        
        ; 处理双引号，切换状态
        if (currentChar = '"') {
            inQuotes := !inQuotes
            output .= currentChar
            continue
        }
        
        ; 如果在双引号中，直接添加字符
        if (inQuotes) {
            output .= currentChar
            continue
        }
        
        if (currentChar = "{" || currentChar = "}") 
				{
            output .= "`n" currentChar "`n"
        } 
				else 
				{
            output .= currentChar
        }
    }
    output:=CleanBracesEmptyLines(output)
    return output
}
; 辅助函数：移除大括号前后的所有空行
CleanBracesEmptyLines(docString) {
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
text:=
(
'if(true)



			{"fdf{dd""f{""""""
	 }"
return
 if    (true)
{
return}   
} else {
dfaf()}
'
)
    processed := AddNewlinesToBraces(text)
print(processed)
;print(TrimBracesEmptyLines(text2))
; 输出结果
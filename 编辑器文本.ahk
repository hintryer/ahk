#Requires AutoHotkey v2.0

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
        ; 清空编辑器文本
        codeLength := StrLen(codetext)
        ControlSetText("", "Scintilla1", "ahk_id " SciTEHwnd)
        oSciTE.InsertText(fmtext)
    }
    else
    {
        fmtext:=internalFormat(codetext,options2)
        ; 清空编辑器文本
        oSciTE.ReplaceSel(fmtext)
    }
}
internalFormat(df,op)
{
    return 1
}
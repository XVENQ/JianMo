/*
    relink_textures.ms —— 批量重链缺失贴图
    3ds Max 2022 / MaxScript
    用法：3ds Max → 脚本 → 运行脚本 → 选择本文件

    背景：课程机房里的 .max 把贴图存成了 C:\Users\Administrator\Desktop\...
    之类的绝对路径，换机器后全部失效。本仓库已把每件作品用到的贴图
    放在同级 textures\ 目录（保持原文件名），本脚本负责把引用指过去。

    行为：遍历 works\ 与 archive\ 下所有 .max → 打开 → 若贴图缺失，
          就在同级 textures\ 里按同名查找 → 重链 → 询问是否保存。
*/
(
    local scriptPath = getFilenamePath (getSourceFileName())
    local root = (dotNetClass "System.IO.Path").GetFullPath (scriptPath + "..\\")
    local logFile = createFile (root + "relink_log.txt")

    local allMax = (getFiles (root + "works\\*\\*.max")) + (getFiles (root + "archive\\*\\*.max"))
    format "== 贴图重链 ==\n共 % 个 .max\n\n" allMax.count to:logFile

    local fixedTotal = 0
    local fileCount = 0

    for f in allMax do
    (
        local texDir = (getFilenamePath f) + "textures\\"
        if not (doesFileExist texDir) do continue

        format "--- %\n" (getFilenameFile f) to:logFile
        local fixed = 0

        try
        (
            loadMaxFile f quiet:true

            -- 所有位图贴图节点
            for m in (getClassInstances Bitmaptexture) do
            (
                local fn = m.filename
                if fn != undefined and fn != "" and not (doesFileExist fn) do
                (
                    local cand = texDir + filenameFromPath (fn as string)
                    if doesFileExist cand do
                    (
                        m.filename = cand
                        fixed += 1
                        format "    % -> textures\\\n" (filenameFromPath (fn as string)) to:logFile
                    )
                    else
                        format "    [未找到] %\n" (filenameFromPath (fn as string)) to:logFile
                )
            )

            -- IFL / 其他外部文件不处理，仅提示
            if fixed > 0 do
            (
                if (queryBox ("已为 " + (getFilenameFile f) + " 重链 " + fixed as string + " 张贴图。\n\n是否保存该文件？") title:"relink_textures") == true do
                (
                    saveMaxFile f quiet:true
                    format "    已保存\n" to:logFile
                )
            )
            fixedTotal += fixed
            fileCount += 1
        )
        catch
        (
            format "    !! 失败: %\n" (getCurrentException()) to:logFile
        )
    )

    format "\n扫描 % 个文件，共重链 % 张贴图\n" fileCount fixedTotal to:logFile
    close logFile
    messageBox ("扫描 " + fileCount as string + " 个文件，共重链 " + fixedTotal as string + " 张贴图。\n详细日志见 relink_log.txt") title:"relink_textures"
)

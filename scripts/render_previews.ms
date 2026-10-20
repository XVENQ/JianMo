/*
    render_previews.ms —— 批量渲染作品集预览图
    3ds Max 2022 / MaxScript
    用法：3ds Max → 脚本 → 运行脚本 → 选择本文件

    脚本会遍历 works/ 下每个作品目录，打开 .max，自动布相机与两盏灯，
    各渲染一张着色图和一张线框图到该作品的 preview/ 目录。
    不会保存、也不会改动原始 .max。
*/
(
    -- ===== 可调参数 =====
    local RES = 1200          -- 输出边长（正方形）
    local DO_WIRE = true      -- 是否同时渲染线框图
    local BG = color 52 52 52 -- 背景灰
    local SUN_MUL = 1.15      -- 主光强度
    local FILL_MUL = 0.55     -- 补光强度
    -- ====================

    local scriptPath = getFilenamePath (getSourceFileName())
    local root = (dotNetClass "System.IO.Path").GetFullPath (scriptPath + "..\\")
    local worksDir = root + "works\\"
    local logFile = createFile (root + "render_log.txt")
    local t0 = timeStamp()

    format "== 作品集预览渲染 ==\n根目录: %\n\n" root to:logFile

    local dirs = getDirectories (worksDir + "*")
    local doneCount = 0

    for d in dirs do
    (
        local files = getFiles (d + "*.max")
        if files.count == 0 then continue

        local f = files[1]
        local name = getFilenameFile f
        local prevDir = d + "preview\\"
        makeDir prevDir

        format "--- %\n" name to:logFile

        try
        (
            loadMaxFile f quiet:true

            -- 清掉场景里已有的相机和灯光，避免与自动布光打架
            for o in objects where (superClassOf o == camera or superClassOf o == light) do delete o

            -- 求所有几何体 / 图形的世界包围盒
            local gs = for o in objects where ((superClassOf o == GeometryClass or superClassOf o == Shape) and not o.isHidden) collect o
            if gs.count == 0 do throw "场景里没有可见几何体"

            local mn = gs[1].min
            local mx = gs[1].max
            for o in gs do
            (
                local a = o.min
                local b = o.max
                mn = [amin mn.x a.x, amin mn.y a.y, amin mn.z a.z]
                mx = [amax mx.x b.x, amax mx.y b.y, amax mx.z b.z]
            )

            local c = (mn + mx) / 2.0
            local size = mx - mn
            local radius = (length size) / 2.0
            if radius < 1 then radius = 1

            -- 相机：右前上方等轴测视角
            local dir = normalize [1.0, -1.0, 0.62]
            local camPos = c + dir * (radius * 2.9)
            local camTgt = TargetObject pos:c
            local cam = TargetCamera pos:camPos target:camTgt fov:38.0
            cam.name = "__preview_cam"

            -- 主光 + 补光
            local sun = TargetDirectionalLight pos:(c + [-1.0, 1.0, 1.4] * radius * 2.2) target:(TargetObject pos:c)
            sun.multiplier = SUN_MUL
            sun.name = "__preview_sun"

            local fill = TargetDirectionalLight pos:(c + [1.6, -0.4, 0.5] * radius * 2.0) target:(TargetObject pos:c)
            fill.multiplier = FILL_MUL
            fill.name = "__preview_fill"

            backgroundColor = BG
            renderWidth = RES
            renderHeight = RES

            local outColor = prevDir + "color.png"
            local outWire = prevDir + "wireframe.png"

            render camera:cam outputfile:outColor outputSize:[RES, RES] vfb:off progressbar:false
            format "    着色图 -> %\n" outColor to:logFile

            if DO_WIRE do
            (
                render camera:cam outputfile:outWire outputSize:[RES, RES] vfb:off progressbar:false forceWireframe:true
                format "    线框图 -> %\n" outWire to:logFile
            )

            doneCount += 1
        )
        catch
        (
            format "    !! 失败: %\n" (getCurrentException()) to:logFile
        )
    )

    format "\n完成 % 个作品，用时 % 秒\n" doneCount ((timeStamp() - t0) / 1000.0) to:logFile
    close logFile
    messageBox ("渲染完成：共 " + doneCount as string + " 个作品。\n日志见 render_log.txt") title:"render_previews"
)

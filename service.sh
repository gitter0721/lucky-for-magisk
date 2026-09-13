#!/system/bin/sh


# wind1 ^_^
# 等待系统完全启动
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 获取模块的绝对路径
MODDIR=${0%/*}
DATA_DIR="$MODDIR/data"
LOG_DIR="$MODDIR/log"
LUCKY_DIR="$MODDIR/lucky"
PROP_FILE="$MODDIR/module.prop"
MAX_SIZE=1048576

# 动态获取 module.prop 中的基础描述
BASE_DESC=$(grep '^description=' "$PROP_FILE" | sed -e 's/^description=//' -e 's/ ｜ 当前状态:.*//')
if [ -z "$BASE_DESC" ]; then
    BASE_DESC="开机自动运行 默认端口16601"
fi


# 创建 data 目录
if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
fi

# 创建 log 目录
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

log() {
    # 格式化时间
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$CURRENT_TIME] $1" >> "$LOG_DIR/run.log"
}

LAST_STATE=""
update_status() {
    local current_state="$1"
    # 只有当状态发生变化时，才执行磁盘写入
    if [ "$LAST_STATE" != "$current_state" ]; then
        # 将 module.prop 中的 description= 替换为新的内容
        sed -i "s|^description=.*|description=${BASE_DESC} ｜ 当前状态: ${current_state}|g" "$PROP_FILE"
        LAST_STATE="$current_state"
    fi
}

# ==========================================
# 守护进程：实现 Magisk 开关实时控制 & 崩溃自启
# ==========================================
while true; do
    # 判断模块是否被禁用 (存在 disable 文件代表开关被关掉)
    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
        # 模块被禁用，查找 lucky 是否还在运行
        PID=$(pidof lucky)
        if [ -n "$PID" ]; then
            # 如果正在运行，立刻杀掉进程
            log "已检测到lucky进程:$PID ，准备杀死"
            kill -9 $PID
            log "已结束lucky进程"
        fi
        update_status "🔴已停止 "
    else
        # 模块处于开启状态，查找 lucky 是否在运行
        PID=$(pidof lucky)
        if [ -z "$PID" ]; then
            # 没有运行，尝试启动
            update_status "🟡正在启动..."
            # 追加日志，防止重启覆盖之前的报错信息
            nohup "$LUCKY_DIR/lucky" -cd "$DATA_DIR" >> "$LOG_DIR/run.log" 2>&1 &
            log "lucky已启动"
        else
            # 正常运行中，抓取 PID
            update_status "🟢运行中 (PID: $PID)"
        fi
    fi
    
        # 检查文件是否存在
if [ -f "$LOG_DIR/run.log" ]; then
    # 获取文件当前大小 
    FILE_SIZE=$(stat -c%s "$LOG_DIR/run.log")

    # 判断是否超过设定大小
    if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
        # 清空文件内容，但保留文件
        : > "$LOG_DIR/run.log"
        
        # 记录一次清理日志的操作
        log "日志超过1MB，已执行自动清空。"
    fi
fi
    
    # 每 10 秒钟巡视一次
    sleep 10
done
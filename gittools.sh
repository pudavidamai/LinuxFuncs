fsync() {
    echo "⚠️  警告：此操作将丢弃所有本地更改！"
    read -p "确定要继续吗？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local branch=$(git branch --show-current)
        echo "当前分支: $branch"
        
        # 获取最新远程信息
        git fetch origin
        
        # 硬重置到远程分支
        git reset --hard origin/$branch
        
        # 清理未跟踪的文件和目录
        git clean -fd
        
        echo "✅ 已完成！本地完全同步到 origin/$branch"
    else
        echo "❌ 已取消"
    fi
}

sync() {
    local branch=$(git branch --show-current)
    echo "当前分支: $branch"
    
    # 暂存本地更改
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "📦 正在暂存本地更改..."
        git stash push -u -m "auto-stash before update"
        local stashed=true
    else
        local stashed=false
    fi
    
    # 拉取远程更新
    echo "⬇️  正在拉取远程更新..."
    if git pull --rebase origin $branch; then
        echo "✅ 远程更新拉取成功"
    else
        echo "⚠️  拉取过程中出现冲突，请手动解决"
        return 1
    fi
    
    # 恢复暂存的更改
    if $stashed; then
        echo "📦 正在恢复本地更改..."
        if git stash pop; then
            echo "✅ 本地更改已恢复"
        else
            echo "⚠️  恢复本地更改时出现冲突"
            echo "💡 请手动解决冲突，或使用 'git stash apply' 查看暂存的更改"
        fi
    fi
    
    echo "🎉 完成！远程代码已同步，本地更改已保留"
}

qpush() {
    if [ -z "$1" ]; then
        echo "❌ 请提供提交信息"
        echo "💡 用法: gpush <commit message>"
        return 1
    fi
    
    local branch=$(git branch --show-current)
    
    echo "📦 添加所有更改..."
    git add .
    
    echo "✍️  提交: $1"
    git commit -m "$1"
    
    echo "⬆️  推送到 origin/$branch..."
    git push origin $branch
    
    echo "✅ 完成！已推送到 $branch"
}


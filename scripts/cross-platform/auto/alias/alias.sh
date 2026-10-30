# 使用 eza 代替传统的 ls，添加图标、显示 Git 状态、按目录优先排序
alias ls='eza --icons --git --group-directories-first'
#alias ll='eza -lh --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons' # 树状显示，洞察项目结的神器
alias tree='eza --tree --icons'

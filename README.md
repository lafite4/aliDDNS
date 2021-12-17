# aliDDNS
通过linux 脚本动态修改阿里DDNS解析记录，同时支持IPV6和IPV4。增加对\*和@的通配符的支持，在群晖DSM 6.2测试通过。
更新语法：

 使用方法：

 方法1. 外部参数
 aliddns.sh <aliddns_ak> <aliddns_sk> <aliddns_subdomain> <aliddns_domain> <aliddns_iptype> <aliddns_ttl>
 示例（A 代表 IPv4，AAAA 代表 IPv6）: 
 执行：aliddns.sh "xxxx" "xxx" "test" "mydomain.site" "A" 600
 执行：aliddns.sh "xxxx" "xxx" "test" "mydomain.site" "AAAA" 600

 方法2. 内部参数
 修改源码，将$1,$2,$3,$4,$5,$6 替换为对应参数
 
 示例: 
 aliddns_ak="xxxx"
 aliddns_sk="xxx"
 aliddns_subdomain="test"
 aliddns_domain="mydomain.site"
 aliddns_iptype="A"
 aliddns_ttl=600 
 执行：aliddns.sh

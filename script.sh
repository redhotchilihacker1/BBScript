#!/bin/bash



#export PATH=$PATH:/usr/local/go/bin



if [ $# -gt 2 ]; then

	echo "Usage: ./script.sh <domain>"

	echo "Example: ./script.sh hackerone.com"

	exit 1

fi 



if [ ! -d "$1" ]; then

	mkdir $1

fi



if [ ! -d "$1/thirdlevels" ]; then

	mkdir $1/thirdlevels

fi



if [ ! -d "$1/scans" ]; then

	mkdir $1/scans

fi



if [ ! -d "$1/thirdlevels/subfinder" ]; then

	mkdir $1/thirdlevels/subfinder

fi



if [ ! -d "$1/nmap" ]; then

	mkdir $1/nmap

fi



pwd=$(pwd)



echo

echo "Gathering subdomains with Sublist3r"

echo



python3 ~/Tools/Sublist3r/sublist3r.py -d $1 -o $1/sublist3r.txt

echo $1 >> $1/sublist3r.txt



echo

echo "Gathering subdomains with Subfinder"

echo



subfinder -d $1 -o $1/subfinder.txt



echo

echo "Gathering subdomains with Assetfinder"

echo



assetfinder $1 -subs-only  | tee -a $1/assetfinder.txt



echo

echo "Gathering subdomains with Amass"

echo



amass enum -passive -d $1 -o $1/amass.txt



echo

echo "Gathering subdomains with Crt.sh"

echo



curl -s https://crt.sh/?q=%25.$1 | grep "$1" | grep "<TD>" | cut -d">" -f2 | cut -d"<" -f1 | sort -u | sed s/*.//g > $1/crtsh.txt

cat $1/crtsh.txt



echo

echo "Compiling third-level domains"

echo



cat $1/sublist3r.txt >> $1/trash.txt

cat $1/assetfinder.txt >> $1/trash.txt

cat $1/amass.txt >> $1/trash.txt

cat $1/subfinder.txt >> $1/trash.txt

cat $1/crtsh.txt >> $1/trash.txt

sort -u $1/trash.txt | sed 's/\*.//' | sed 's/BR/\n/g' | grep ${1} >> $1/all_subdomains.txt

cat $1/all_subdomains.txt | grep -Po "(\w+\.\w+\.\w+)$" | sort -u >>  $1/third-level.txt



for domain in $(cat $1/third-level.txt);

do subfinder -d $domain -o $1/thirdlevels/subfinder/$domain.txt; cat $1/thirdlevels/subfinder/$domain.txt | sort -u >> $1/all_subdomains.txt;done



cat $1/all_subdomains.txt | sort -u | grep ${1} >> $1/final_subdomains.txt



echo

echo "Passing subdomains to Httpx"

echo



httpx -l $1/final_subdomains.txt -o $1/httpx_statuscodes.txt -status-code -no-color

sed 's/......$//' $1/httpx_statuscodes.txt >> $1/httpx_clean.txt



echo

echo "Passing subdomains to Httprobe"

echo



cat $1/final_subdomains.txt | httprobe -c 5 >> $1/httprobe_results.txt



echo

echo "Checking for subdomain takeover"

echo



tko-subs -domains $1/final_subdomains.txt -data ~/go/pkg/mod/github.com/anshumanbh/tko-subs@v0.0.0-20210103051427-5fd34e856644/providers-data.csv

#subjack -w $1/final_subdomains.txt -o $1/subdomain_takeover.txt -c ~/Tools/fingerprints.json (deprecated)



echo

echo "Identifying technologies"

echo



nuclei -l $1/httpx_clean.txt -t ~/nuclei-templates/technologies/ -o $1/technologies.txt -silent



echo

echo "Taking Screenshots with Aquatone"

echo



cat $1/httpx_clean.txt | ~/Tools/aquatone -chrome-path /usr/bin/chromium -out $1/aquatone -threads 1



echo

echo "Querying Archive.org & AlienVault"

echo



cat $1/httpx_clean.txt | waybackurls -no-subs > $1/remove.txt

cat $1/httpx_clean.txt | gau >> $1/remove.txt



cat $1/remove.txt | sort -u > $1/shit_load_of_urls.txt



echo

echo "Crawling for Endpoints With ParamSpider"

echo



mkdir $1/paramspider

for URL in $(<$1/httpx_clean.txt);

do python3 ~/Tools/ParamSpider/paramspider.py -d "${URL}" -o $1/paramspider/${URL};done



echo

echo "Filtering Endpoints for XSS"

echo



ls $1/paramspider/https:/ > $1/paramspider/https:/urls.txt

for URL in $(<$1/paramspider/https:/urls.txt);

do cat "$1/paramspider/https:/${URL}" | kxss;done > $1/xss.txt



echo

echo "Looking for ports that can lead to a vulnerability"

echo



cat $1/httpx_clean.txt | sed 's/https\?:\/\///' > $1/nmap/hosts.txt

nmap -sV -iL $1/nmap/hosts.txt -oN $1/nmap/possible_vulns.txt --open -p9200,8500,2082,9100,50000,8080



echo "9200 --> ElasticSearch"

echo "8500 --> Adobe Coldfusion"

echo "2082 --> cPanel"

echo "9100 --> Kubernetes Kubelet healtz port"

echo "50000 --> SAP Knowledge Warehouse"

echo "8080 --> Atlassian Jira"



echo

echo "Looking for CVE-2023-24488 (Citrix Gateway XSS)"

echo



python3 ~/Tools/CVE-2023-24488-python/CVE-2023-24488.py -f $1/httpx_clean.txt -o $1/cve-2023-24488.txt



rm $1/remove.txt

rm $1/trash.txt

rm $1/all_subdomains.txt

mv $1/amass.txt $1/scans

mv $1/assetfinder.txt $1/scans

mv $1/sublist3r.txt $1/scans

mv $1/subfinder.txt $1/scans

mv $1/crtsh.txt $1/scans

mv $1/third-level.txt $1/thirdlevels



sleep 5


function runbg() {
  if [[ $# -lt 1 ]]; then
     echo -e "\nUsage: $0 <script to run in background>\n"
     return
  fi
  OUTFILE="runbg-$(date +%s).nohup"
  cmd="nohup ${1} >> ${OUTFILE} 2>&1 &"
  echo -e "\n${cmd}\n"
  eval $cmd
}

#!/bin/bash

# Simple jobs that never fails
# Each should be taking 10-30s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_macron() {
    echo '### See if \257\256 \257<\257> is replaced correctly'
    print_it() {
	parallel $2 ::: "echo $1"
	parallel $2 echo ::: "$1"
	parallel $2 echo "$1" ::: "$1"
	parallel $2 echo \""$1"\" ::: "$1"
	parallel $2 echo "$1"{} ::: "$1"
	parallel $2 echo \""$1"\"{} ::: "$1"
    }
    export -f print_it
    parallel --tag -k print_it \
      ::: "$(perl -e 'print "\257"')" "$(perl -e 'print "\257\256"')" \
      "$(perl -e 'print "\257\257\256"')" \
      "$(perl -e 'print "\257<\257<\257>\257>"')" \
      ::: -X -q -Xq -k
}

par_kill_hup() {
    echo '### Are children killed if GNU Parallel receives HUP? There should be no sleep at the end'

    parallel -j 2 -q bash -c 'sleep {} & pid=$!; wait $pid' ::: 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 &
    T=$!
    sleep 9.9
    pstree $$
    kill -HUP $T
    sleep 2
    pstree $$
}

par_parset() {
    echo '### test parset'
    . `which env_parallel.bash`

    echo 'Put output into $myarray'
    parset myarray -k seq 10 ::: 14 15 16
    echo "${myarray[1]}"

    echo 'Put output into vars "$seq, $pwd, $ls"'
    parset "seq pwd ls" -k ::: "seq 10" pwd ls
    echo "$seq"

    echo 'Put output into vars ($seq, $pwd, $ls)':
    into_vars=(seq pwd ls)
    parset "${into_vars[*]}" -k ::: "seq 5" pwd ls
    echo "$seq"

    echo 'The commands to run can be an array'
    cmd=("echo '<<joe  \"double  space\"  cartoon>>'" "pwd")
    parset data -k ::: "${cmd[@]}"
    echo "${data[0]}"
    echo "${data[1]}"

    echo 'You cannot pipe into parset, but must use a tempfile'
    seq 10 > /tmp/parset_input_$$
    parset res -k echo :::: /tmp/parset_input_$$
    echo "${res[0]}"
    echo "${res[9]}"
    rm /tmp/parset_input_$$

    echo 'or process substitution'
    parset res -k echo :::: <(seq 0 10)
    echo "${res[0]}"
    echo "${res[9]}"

    echo 'Commands with newline require -0'
    parset var -k -0 ::: 'echo "line1
line2"' 'echo "command2"'
    echo "${var[0]}"
}

par_parset2() {
    . `which env_parallel.bash`
    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[5]}

    echo '### env_parset'
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
    env_parset arr1 myecho ::: foo bar baz
    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myecho ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myecho ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myecho ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[5]}"

    echo 'bug #52507: parset arr1 -v echo ::: fails'
    parset arr1 -v seq ::: 1 2 3
    echo "${arr1[2]}"
}

par_perlexpr_repl() {
    echo '### {= and =} in different groups separated by space'
    parallel echo {= s/a/b/ =} ::: a
    parallel echo {= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{=s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{= {= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{={=s/a/b/=} ::: a
    parallel echo {= s/a/b/ =} {={==} ::: a
    parallel echo {={= =} ::: a
    parallel echo {= {= =} ::: a
    parallel echo {= {= =} =} ::: a

    echo '### bug #45842: Do not evaluate {= =} twice'
    parallel -k echo '{=  $_=++$::G =}' ::: {1001..1004}
    parallel -k echo '{=1 $_=++$::G =}' ::: {1001..1004}
    parallel -k echo '{=  $_=++$::G =}' ::: {1001..1004} ::: {a..c}
    parallel -k echo '{=1 $_=++$::G =}' ::: {1001..1004} ::: {a..c}

    echo '### bug #45939: {2} in {= =} fails'
    parallel echo '{= s/O{2}//=}' ::: OOOK
    parallel echo '{2}-{=1 s/O{2}//=}' ::: OOOK ::: OK
}

par_END() {
    echo '### Test -i and --replace: Replace with argument'
    (echo a; echo END; echo b) | parallel -k -i -eEND echo repl{}ce
    (echo a; echo END; echo b) | parallel -k --replace -eEND echo repl{}ce
    (echo a; echo END; echo b) | parallel -k -i+ -eEND echo repl+ce
    (echo e; echo END; echo b) | parallel -k -i'*' -eEND echo r'*'plac'*'
    (echo a; echo END; echo b) | parallel -k --replace + -eEND echo repl+ce
    (echo a; echo END; echo b) | parallel -k --replace== -eEND echo repl=ce
    (echo a; echo END; echo b) | parallel -k --replace = -eEND echo repl=ce
    (echo a; echo END; echo b) | parallel -k --replace=^ -eEND echo repl^ce
    (echo a; echo END; echo b) | parallel -k -I^ -eEND echo repl^ce

    echo '### Test -E: Artificial end-of-file'
    (echo include this; echo END; echo not this) | parallel -k -E END echo
    (echo include this; echo END; echo not this) | parallel -k -EEND echo

    echo '### Test -e and --eof: Artificial end-of-file'
    (echo include this; echo END; echo not this) | parallel -k -e END echo
    (echo include this; echo END; echo not this) | parallel -k -eEND echo
    (echo include this; echo END; echo not this) | parallel -k --eof=END echo
    (echo include this; echo END; echo not this) | parallel -k --eof END echo
}

par_xargs_compat() {
    echo xargs compatibility

    echo '### Test -L -l and --max-lines'
    (echo a_b;echo c) | parallel -km -L2 echo
    (echo a_b;echo c) | parallel -k -L2 echo
    (echo a_b;echo c) | xargs -L2 echo

    echo '### xargs -L1 echo'
    (echo a_b;echo c) | parallel -km -L1 echo
    (echo a_b;echo c) | parallel -k -L1 echo
    (echo a_b;echo c) | xargs -L1 echo

    echo 'Lines ending in space should continue on next line'
    echo '### xargs -L1 echo'
    (echo a_b' ';echo c;echo d) | parallel -km -L1 echo
    (echo a_b' ';echo c;echo d) | parallel -k -L1 echo
    (echo a_b' ';echo c;echo d) | xargs -L1 echo

    echo '### xargs -L2 echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel -km -L2 echo
    (echo a_b' ';echo c;echo d;echo e) | parallel -k -L2 echo
    (echo a_b' ';echo c;echo d;echo e) | xargs -L2 echo

    echo '### xargs -l echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel -l -km echo # This behaves wrong
    (echo a_b' ';echo c;echo d;echo e) | parallel -l -k echo # This behaves wrong
    (echo a_b' ';echo c;echo d;echo e) | xargs -l echo

    echo '### xargs -l2 echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel -km -l2 echo
    (echo a_b' ';echo c;echo d;echo e) | parallel -k -l2 echo
    (echo a_b' ';echo c;echo d;echo e) | xargs -l2 echo

    echo '### xargs -l1 echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel -km -l1 echo
    (echo a_b' ';echo c;echo d;echo e) | parallel -k -l1 echo
    (echo a_b' ';echo c;echo d;echo e) | xargs -l1 echo

    echo '### xargs --max-lines=2 echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel -km --max-lines 2 echo
    (echo a_b' ';echo c;echo d;echo e) | parallel -k --max-lines 2 echo
    (echo a_b' ';echo c;echo d;echo e) | xargs --max-lines=2 echo

    echo '### xargs --max-lines echo'
    (echo a_b' ';echo c;echo d;echo e) | parallel --max-lines -km echo # This behaves wrong
    (echo a_b' ';echo c;echo d;echo e) | parallel --max-lines -k echo # This behaves wrong
    (echo a_b' ';echo c;echo d;echo e) | xargs --max-lines echo

    echo '### test too long args'
    perl -e 'print "z"x1000000' | parallel echo 2>&1
    perl -e 'print "z"x1000000' | xargs echo 2>&1
    (seq 1 10; perl -e 'print "z"x1000000'; seq 12 15) | stdsort parallel -j1 -km -s 10 echo
    (seq 1 10; perl -e 'print "z"x1000000'; seq 12 15) | stdsort xargs -s 10 echo
    (seq 1 10; perl -e 'print "z"x1000000'; seq 12 15) | stdsort parallel -j1 -kX -s 10 echo

    echo '### Test -x'
    (seq 1 10; echo 12345; seq 12 15) | stdsort parallel -j1 -km -s 10 -x echo
    (seq 1 10; echo 12345; seq 12 15) | stdsort parallel -j1 -kX -s 10 -x echo
    (seq 1 10; echo 12345; seq 12 15) | stdsort xargs -s 10 -x echo
    (seq 1 10; echo 1234;  seq 12 15) | stdsort parallel -j1 -km -s 10 -x echo
    (seq 1 10; echo 1234;  seq 12 15) | stdsort parallel -j1 -kX -s 10 -x echo
    (seq 1 10; echo 1234;  seq 12 15) | stdsort xargs -s 10 -x echo
}

par_sem_2jobs() {
    echo '### Test semaphore 2 jobs running simultaneously'
    parallel --semaphore --id 2jobs -u -j2 'echo job1a 1; sleep 4; echo job1b 3'
    sleep 0.5
    parallel --semaphore --id 2jobs -u -j2 'echo job2a 2; sleep 4; echo job2b 5'
    sleep 0.5
    parallel --semaphore --id 2jobs -u -j2 'echo job3a 4; sleep 4; echo job3b 6'
    parallel --semaphore --id 2jobs --wait
    echo done
}

par_semaphore() {
    echo '### Test if parallel invoked as sem will run parallel --semaphore'
    sem --id as_sem -u -j2 'echo job1a 1; sleep 3; echo job1b 3'
    sleep 0.5
    sem --id as_sem -u -j2 'echo job2a 2; sleep 3; echo job2b 5'
    sleep 0.5
    sem --id as_sem -u -j2 'echo job3a 4; sleep 3; echo job3b 6'
    sem --id as_sem --wait
    echo done
}

par_line_buffer() {
    echo "### --line-buffer"
    tmp1=$(tempfile)
    tmp2=$(tempfile)

    seq 10 | parallel -j20 --line-buffer  'seq {} 10 | pv -qL 10' > $tmp1
    seq 10 | parallel -j20                'seq {} 10 | pv -qL 10' > $tmp2
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer() {
    echo "### --pipe --line-buffer"
    tmp1=$(tempfile)
    tmp2=$(tempfile)

    nowarn() {
	# Ignore certain warnings
	# parallel: Warning: Starting 11 processes took > 2 sec.
	# parallel: Warning: Consider adjusting -j. Press CTRL-C to stop.
	grep -v '^parallel: Warning: (Starting|Consider)'
    }

    export PARALLEL="-N10 -L1 --pipe  -j20 --tagstring {#}"
    seq 200| parallel --line-buffer pv -qL 10 > $tmp1 2> >(nowarn)
    seq 200| parallel               pv -qL 10 > $tmp2 2> >(nowarn)
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer_compress() {
    echo "### --pipe --line-buffer --compress"
    seq 200| parallel -N10 -L1 --pipe  -j20 --line-buffer --compress --tagstring {#} pv -qL 10 | wc
}

par__pipepart_spawn() {
    echo '### bug #46214: Using --pipepart doesnt spawn multiple jobs in version 20150922'
    seq 1000000 > /tmp/num1000000
    stdout parallel --pipepart --progress -a /tmp/num1000000 --block 10k -j0 true |
	grep 1:local | perl -pe 's/\d\d\d/999/g; s/[2-9]/2+/g;'
}

par__pipe_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipe --tee'

    random100M() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 100M;
    }
    random100M | parallel --pipe --tee cat ::: {1..3} | LC_ALL=C wc -c
}

par__pipepart_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipepart --tee'

    export TMPDIR=/dev/shm/parallel
    mkdir -p $TMPDIR
    random100M() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 100M;
    }
    tmp=$(mktemp)
    random100M >$tmp
    parallel --pipepart --tee -a $tmp cat ::: {1..3} | LC_ALL=C wc -c
    rm $tmp
}

par__memleak() {
    echo "### Test memory consumption stays (almost) the same for 30 and 300 jobs"
    echo "should give 1 == true"

    mem30=$( nice stdout time -f %M parallel -j2 true :::: <(perl -e '$a="x"x60000;for(1..30){print $a,"\n"}') );
    mem300=$( nice stdout time -f %M parallel -j2 true :::: <(perl -e '$a="x"x60000;for(1..300){print $a,"\n"}') );
    echo "Memory use should not depend very much on the total number of jobs run\n";
    echo "Test if memory consumption(300 jobs) < memory consumption(30 jobs) * 110% ";
    echo $(($mem300*100 < $mem30 * 110))
}

par_slow_total_jobs() {
    echo 'bug #51006: Slow total_jobs() eats job'
    (echo a; sleep 15; echo b; sleep 15; seq 2) |
	parallel -k echo '{=total_jobs()=}' 2> >(perl -pe 's/\d/X/g')
}

par_interactive() {
    echo '### Test -p --interactive'
    cat >/tmp/parallel-script-for-expect <<_EOF
#!/bin/bash

seq 1 3 | parallel -k -p "sleep 0.1; echo opt-p"
seq 1 3 | parallel -k --interactive "sleep 0.1; echo opt--interactive"
_EOF
    chmod 755 /tmp/parallel-script-for-expect

    (
	expect -b - <<_EOF
spawn /tmp/parallel-script-for-expect
expect "echo opt-p 1"
send "y\n"
expect "echo opt-p 2"
send "n\n"
expect "echo opt-p 3"
send "y\n"
expect "opt-p 1"
expect "opt-p 3"
expect "echo opt--interactive 1"
send "y\n"
expect "echo opt--interactive 2"
send "n\n"
#expect "opt--interactive 1"
expect "echo opt--interactive 3"
send "y\n"
expect "opt--interactive 3"
send "\n"
_EOF
	echo
    ) | perl -ne 's/\r//g;/\S/ and print' |
	# Race will cause the order to change
	LC_ALL=C sort
}

par_k() {
    echo '### Test -k'
    ulimit -n 50
    (echo "sleep 3; echo begin";
     seq 1 30 |
	 parallel -j1 -kq echo "sleep 1; echo {}";
     echo "echo end") |
	stdout nice parallel -k -j0 |
	grep -Ev 'No more file handles.|Raising ulimit -n' |
	perl -pe '/parallel:/ and s/\d/X/g'
}

par_k_linebuffer() {
    echo '### bug #47750: -k --line-buffer should give current job up to now'

    parallel --line-buffer --tag -k 'seq {} | pv -qL 10' ::: {10..20}
    parallel --line-buffer -k 'echo stdout top;sleep 1;echo stderr in the middle >&2; sleep 1;echo stdout' ::: end 2>&1
}

par_maxlinelen_m_I() {
    echo "### Test max line length -m -I"

    seq 1 60000 | parallel -I :: -km -j1 echo a::b::c | LC_ALL=C sort >/tmp/114-a$$;
    md5sum </tmp/114-a$$;
    export CHAR=$(cat /tmp/114-a$$ | wc -c);
    export LINES=$(cat /tmp/114-a$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-a$$
}

par_maxlinelen_X_I() {
    echo "### Test max line length -X -I"

    seq 1 60000 | parallel -I :: -kX -j1 echo a::b::c | LC_ALL=C sort >/tmp/114-b$$;
    md5sum </tmp/114-b$$;
    export CHAR=$(cat /tmp/114-b$$ | wc -c);
    export LINES=$(cat /tmp/114-b$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-b$$
}

par_compress_fail() {
    echo "### bug #41609: --compress fails"
    seq 12 | parallel --compress --compress-program gzip -k seq {} 10000 | md5sum
    seq 12 | parallel --compress -k seq {} 10000 | md5sum
}

par_results_csv() {
    echo "bug #: --results csv"

    doit() {
	parallel -k $@ --results -.csv echo ::: H2 22 23 ::: H1 11 12;
    }
    export -f doit
    parallel -k --tag doit ::: '--header :' '' \
	::: --tag '' ::: --files '' ::: --compress '' |
    perl -pe 's:/par......par:/tmpfile:g;s/\d+\.\d+/999.999/g'
}

par_results_compress() {
    tmp=$(mktemp)
    rm "$tmp"
    parallel --results $tmp --compress echo ::: 1 | wc -l
    parallel --results $tmp echo ::: 1 | wc -l
    rm -r "$tmp"
}

par_kill_children_timeout() {
    echo '### Test killing children with --timeout and exit value (failed if timed out)'
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
    doit() {
	for i in `seq 100 120`; do
	    bash -c "(sleep $i)" &
	    sleep $i &
	done;
	wait;
	echo No good;
    }
    export -f doit
    parallel --timeout 3 doit ::: 1000000000 1000000001
    echo $?;
    sleep 2;
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
}

par_tmux_fg() {
    echo 'bug #50107: --tmux --fg should also write how to access it'
    stdout parallel --tmux --fg sleep ::: 3 | perl -pe 's/.tmp\S+/tmp/'
}


par_retries_all_fail() {
    echo "bug #53748: -k --retries 10 + out of filehandles = blocking"
    ulimit -n 30
    seq 8 |
	parallel -k -j0 --retries 2 --timeout 0.1 'echo {}; sleep {}; false' 2>/dev/null
}

par_sockets_cores_threads() {
    echo '### Test --number-of-sockets/cores/threads'
    parallel --number-of-sockets
    parallel --number-of-cores
    parallel --number-of-threads
    parallel --number-of-cpus

    echo '### Test --use-sockets-instead-of-threads'
    (seq 1 4 |
	 stdout parallel --use-sockets-instead-of-threads -j100% sleep) &&
	echo sockets done &
    (seq 1 4 | stdout parallel -j100% sleep) && echo threads done &
    wait
    echo 'Threads should complete first on machines with less than 8 sockets'
}

par_long_line_remote() {
    echo '### Deal with long command lines on remote servers'
    perl -e "print(((\"'\"x5000).\"\\n\")x6)" |
	parallel -j1 -S lo -N 10000 echo {} |wc
    perl -e 'print((("\$"x5000)."\n")x50)' |
	parallel -j1 -S lo -N 10000 echo {} |wc
}


export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --joblog /tmp/jl-`basename $0` -j10 --tag -k '{} 2>&1'

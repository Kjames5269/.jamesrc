for i in $(/bin/ls /Users/$(whoami)/.jamesrc/_*.sh); do
	source $i
done


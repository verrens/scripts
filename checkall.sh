find -maxdepth 2 -name '_darcs' | awk -F/ '{print $2;}' | xargs -i /bin/sh -c "echo Checkout {}; darcs whatsnew -s --repodir={}; darcs pull --repodir={} -aq; darcs push --repodir={} -aq"

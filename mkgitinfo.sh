#!/bin/sh
# Copyright 2015 Brent Longborough
# Part of gitinfo2 package Version 2
# Release 2.0.7 2015-11-22
# Please read gitinfo2.pdf for licencing and other details
# -----------------------------------------------------
# Post-{commit,checkout,merge} hook for the gitinfo2 package
#
SRCFILE=doc/Assembler.tex

# Get the first tag found in the history from the current HEAD
FIRSTTAG=$(git describe --tags --always --dirty='-*' 2>/dev/null)
# Get the first tag in history that looks like a Release
#RELTAG=$(git describe --tags --long --always --dirty='-*' --match '[0-9]*.*' 2>/dev/null)
# tmcintos modified for krusader repository
RELTAG=$(git describe --tags --long --always --dirty='-*' --match 'KRUSADER-v[0-9]*.*' 2>/dev/null)
# tmcintos added REPOURL
REPOURL=$(git config --get remote.origin.url 2>/dev/null)

# tmcintos modified to add DRAFTMODE and DIRTYMODE 

# Check if HEAD is at the latest tag
HEADTAG=$(git describe --tags --exact-match HEAD 2>/dev/null)

# Check if the working directory is dirty
if git diff --quiet --ignore-submodules HEAD && git diff --cached --quiet --ignore-submodules; then
    DIRTYMODE="false"  # No changes, clean repo
else
    DIRTYMODE="true"   # Changes present, repo is dirty
fi

# Determine draft status: only draft if not dirty and HEAD is not at the latest tag
if [ "$DIRTYMODE" = "true" ]; then
    DRAFTMODE="false"  # If dirty, it should not be marked as draft
elif [ "$HEADTAG" = "$RELTAG" ]; then
    DRAFTMODE="false"  # If HEAD is at the latest tag, not a draft
else
    DRAFTMODE="true"   # If clean and not at latest tag, it's a draft
fi

# Hoover up the metadata
# tmcintos use authemail to convey REPOURL
# tmcintos use last commit of $SRCFILE and use branch name instead of %d in refnames
git --no-pager log -1 --date=short --decorate=short \
    --pretty=format:"\usepackage[%
        shash={%h},
        lhash={%H},
        authname={%an},
        authemail={$REPOURL},
        authsdate={%ad},
        authidate={%ai},
        authudate={%at},
        commname={%cn},
        commemail={%ce},
        commsdate={%cd},
        commidate={%ci},
        commudate={%ct},
        refnames={$(git branch --show-current)},
        firsttagdescribe={$FIRSTTAG},
        reltag={$RELTAG},
        draft={$DRAFTMODE}
    ]{gitexinfo}" $(git log -1 --format="%H" -- $SRCFILE) > .git/gitHeadInfo.gin

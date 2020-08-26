#!/bin/bash
# (C) 2020 dl9pf@gmx.de
# License: GPLv2
# you need bash (not dash!)


DOEMAIL=false
OECOREBRANCH="dunfell"
BITBAKEBRANCH="1.46"
OECOREURL="git://git.openembedded.org/openembedded-core"
OECORESRCDIR="$HOME/oe-core"
OEBOTEMAIL="bot@openembedded.org"
BITBAKEURL="git://git.openembedded.org/bitbake"
BITBAKESRCDIR="$HOME/bitbake"

LAYERINDEXURL="https://layers.openembedded.org"
EVALWORKDIR="$HOME/layerindexchecker"
LAYERFILE="$EVALWORKDIR/layers.json"
FROMEMAIL="foo@bar.org"
MAINTAINEREMAIL="$FROMEMAIL"
NOLAYERSERIESCOMPAT=false
NOLAYERDEPENDS=false
FETCHFAILED=false

[[ -n $1 ]] && OEBRANCH="$1"

do_email_header(){
cat << EOF > $EVALWORKDIR/email.txt
From: ${FROMEMAIL}
To: ${MAINTAINER_EMAILS}
CC: ${FROMEMAIL}
Reply-To: ${OEBOTEMAIL}
Subject: $LAYERNAME failed the layerindex checker for branch $OECOREBRANCH

Hi ${MAINTAINER_NAMES} !

You are listed as a maintainer for layer $LAYERNAME
on layers.openembedded.org (layerindex).

The layer $LAYERNAME has failed the layerindex checker.
The log and error message are below.

To replicate the check, run:

a)
grep LAYERSERIES_COMPAT $LAYERNAME/conf/layer.conf

b)
grep LAYERDEPENDS $LAYERNAME/conf/layer.conf

c)
run layer check script:
- clone oe-core ($OECOREBRANCH) and bitbake ($BITBAKEBRANCH) or use poky ($OECOREBRANCH)
  source oe-core/oe-init-build-env
  export LAYERSDIR=\$(pwd)/layers
  mkdir \$LAYERSDIR
  echo "BBLAYERS_FETCH_DIR = \\"\$LAYERSDIR\\" " >> conf/auto.conf
  bitbake-layers layerindex-fetch -b $OECOREBRANCH $LAYERNAME
  yocto-check-layer --dependency \$LAYERSDIR/ -- \$LAYERSDIR/$LAYERNAME


This is an automated email.  For questions, please email bot@openembedded.org .


---- Issues found and log follows ----

*$LAYERNAME* did not pass the following test:

EOF
}

do_wiki_header(){
cat << EOF >> $EVALWORKDIR/wiki.txt
== $LAYERNAME ==

The layer $LAYERNAME was tested for:

a) grep LAYERSERIES_COMPAT $LAYERNAME/conf/layer.conf

b) grep LAYERDEPENDS $LAYERNAME/conf/layer.conf

c) run layer check script:  yocto-check-layer (from OE-core repo)


If there are issues found they are listed below:

EOF
}

do_email_layerseriescompat(){
cat << EOF >> $EVALWORKDIR/email.txt
- no LAYERSERIES_COMPAT declared
  Please add LAYERSERIES_COMPAT to your conf/layer.conf!
  Example:
    LAYERSERIES_COMPAT_foolayer = "$OECOREBRANCH"
EOF

#sendmail -v -d $MAINTAINEREMAIL < $EVALWORKDIR/email.txt
}

do_wiki_layerseriescompat(){
cat << EOF >> $EVALWORKDIR/wiki.txt

=== LAYERSERIES_COMPAT missing ===

The layer $LAYERNAME is missing LAYERSERIES_COMPAT in its conf/layer.conf.

EOF
}

do_email_layerdepends(){
cat << EOF >> $EVALWORKDIR/email.txt
- no LAYERDEPENDS declared
  Please add LAYERDEPENDS to your conf/layer.conf !
  Example:
    LAYERDEPENDS_foolayer = "core openembedded-layer meta-python"
EOF
}

do_wiki_layerdepends(){
cat << EOF >> $EVALWORKDIR/wiki.txt

=== LAYERDEPENDS missing ===

The layer $LAYERNAME is missing LAYERDEPENDS in its conf/layer.conf.

EOF
}


do_email_layercheck(){
cat << EOF >> $EVALWORKDIR/email.txt
- yocto-check-layer did not succeed and the error message was:

$ERRORMSG


Full log:
#########
EOF

cat LOGFILE >> $EVALWORKDIR/email.txt

cat << EOF >> $EVALWORKDIR/email.txt

#########
END

EOF
}

do_wiki_layercheck(){
cat << EOF >> $EVALWORKDIR/wiki.txt

=== yocto-check-layer failed ===

- yocto-check-layer did not succeed and the error message was:

<pre>
EOF

echo "$ERRORMSG" | sed -e "s#==.*#----#g" >> $EVALWORKDIR/wiki.txt

cat << EOF >> $EVALWORKDIR/wiki.txt
</pre>

==== Full log ====

<pre>

EOF

cat LOGFILE | sed -e "s#==.*#----#g" >> $EVALWORKDIR/wiki.txt

cat << EOF >> $EVALWORKDIR/wiki.txt

</pre>

EOF

}


do_email_footer(){
cat << EOF >> $EVALWORKDIR/email.txt

Please update your layer.

Thank you!

---
bot@openembedded.org

EOF

do_wikifooter(){
cat << EOF >> $EVALWORKDIR/wiki.txt

----

EOF
}


# do never send email ;) . uncomment to send.
#$DOEMAIL && sendmail $MAINTAINEREMAIL < $EVALWORKDIR/email.txt
cp $EVALWORKDIR/email.txt $EVALWORKDIR/${LAYERNAME}.email-${count}

}

# get OE-core
if [[ ! -d $OECORESRCDIR ]] ; then
    # clone oe-core
    git clone -b $OECOREBRANCH $OECOREURL $OECORESRCDIR
else
    # update to tip of branch
    pushd $OECORESRCDIR
    git remote -v update
    git checkout $OECOREBRANCH || git checkout -b $OECOREBRANCH origin/$OECOREBRANCH
    git reset --hard origin/$OECOREBRANCH
    popd
fi

# get bitbake
if [[ ! -d $BITBAKESRCDIR ]] ; then
    git clone -b $BITBAKEBRANCH $BITBAKEURL $BITBAKESRCDIR
    git remote -v update
else
    pushd $BITBAKESRCDIR
    git remote -v update
    #git checkout $BITBAKEBRANCH || git checkout -b $BITBAKEBRANCH origin/$BITBAKEBRANCH
    #git reset --hard origin/$BITBAKEBRANCH
    popd
fi

if [[ ! -d $EVALWORKDIR ]] ; then
    mkdir $EVALWORKDIR
#else
    # for now we woul
    #rm -rf $EVALWORKDIR
    #mkdir $EVALWORKDIR
fi
cd $EVALWORKDIR
set -x
# pull down the layerindex
if [[ -f ../layers.json ]] ; then
cp ../layers.json .
fi

if [[ ! -f $LAYERFILE ]] ; then
    curl $LAYERINDEXURL/layerindex/api/layers/ > $LAYERFILE
fi

#set -x
count=0
# loop over the uniq URLs
#for i in meta-arm ; do
#for i in meta-acrn ; do
for i in `cat $LAYERFILE | jq -r --arg BRANCH $OECOREBRANCH -c '.[] | select(.branch.name==$BRANCH) | .layer.name' | sort | uniq` ; do

    sleep 0.5

    NOLAYERSERIESCOMPAT=false
    NOLAYERDEPENDS=false

    #SKIP BLACKLISTed layers
    grep -q $i $EVALWORKDIR/../BLACKLIST && echo "$i=y" >> $EVALWORKDIR/layerstested && continue
    count=$((count+1))
    pwd
    grep -q "$i=y" layerstested && continue
    LAYERNAME=$i
    echo "#### Layername: $i ####"

    # Pull variables out of the layerindex json
    # vcs_uri
    LAYERURL=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH ' .[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .layer.vcs_url'`
    LAYERSUBDIR=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH ' .[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .vcs_subdir'`
    echo "LAYERSUBDIR=\"$LAYERSUBDIR\""
    MAINTAINERS=`cat $LAYERFILE | jq -M --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH '.[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .maintainers[]'`
    #echo "$MAINTAINERS"
    MAINTAINER_NAME1=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH '.[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .maintainers[0].name'`
    MAINTAINER_EMAIL1=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH '.[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .maintainers[0].email'`
    MAINTAINER_NAME2=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH '.[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .maintainers[1].name'`
    MAINTAINER_EMAIL2=`cat $LAYERFILE | jq -r --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH '.[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH) | .maintainers[1].email'`

    #read aw

    # cope with multiple maintainers (2 right now)
    if test x"null" != x"$MAINTAINER_EMAIL2" ; then
        MAINTAINER_NAMES="$MAINTAINER_NAME1 & $MAINTAINER_NAME2"
        MAINTAINER_EMAILS="$MAINTAINER_EMAIL1,$MAINTAINER_EMAIL2"
    else
        MAINTAINER_NAMES="$MAINTAINER_NAME1"
        MAINTAINER_EMAILS="$MAINTAINER_EMAIL1"
    fi

    # SKIP MAINTAINER BLACKLIST
    grep -q $MAINTAINER_EMAIL1 $EVALWORKDIR/../MAINTAINERBLACKLIST && echo "$i=y" >> $EVALWORKDIR/layerstested && continue
    grep -q $MAINTAINER_EMAIL2 $EVALWORKDIR/../MAINTAINERBLACKLIST && echo "$i=y" >> $EVALWORKDIR/layerstested && continue

    TMP=`mktemp -d --tmpdir=$(pwd) --suffix="-$count"`
    #echo "RUNNING in $TMP"
    pushd $TMP
    # source env, configure FETCH_DIR
    source $OECORESRCDIR/oe-init-build-env $TMP/build
    export BBLAYERS_FETCH_DIR=$TMP/layers-under-test/


    # HACK#1 due to not using poky ... aka this is a poky-ism ... or missing in oe-core default configs.
    cat << EOF >> conf/auto.conf
# for running the bitbake-layers fetch, we define the output directory
BBLAYERS_FETCH_DIR = "$BBLAYERS_FETCH_DIR"

# hack:
# set mesa
PREFERRED_PROVIDER_virtual/egl = "mesa"
PREFERRED_PROVIDER_virtual/libgl = "mesa"
PREFERRED_PROVIDER_virtual/libgles1 = "mesa"
PREFERRED_PROVIDER_virtual/libgles2 = "mesa"
PREFERRED_PROVIDER_virtual/mesa = "mesa"

# hack:
DISTRO_FEATURES += "opengl wayland x11"
EOF

    mkdir -p $BBLAYERS_FETCH_DIR

    # clone info from layerindex
    bitbake-layers -d layerindex-fetch -b $OECOREBRANCH $LAYERNAME
    echo "XXXX: $?"
    ls $BBLAYERS_FETCH_DIR
    if [[ $(ls $BBLAYERS_FETCH_DIR | wc -l) -eq 0 ]]; then
	echo "FAILED TO FETCH" 
	echo $LAYERNAME > $EVALWORKDIR/FETCHISSUES 
	do_wiki_header
	echo "layerindex-fetch failed" >> $EVALWORKDIR/wiki.txt
	echo "" >> $EVALWORKDIR/wiki.txt
	echo "----" >> $EVALWORKDIR/wiki.txt
	echo "" >> $EVALWORKDIR/wiki.txt
	echo $i >> $EVALWORKDIR/FETCHFAILED
	do_wikifooter
	echo $i
#	read aw
	continue
    fi

    # HACK#2 fixup meta-oe: aka apply https://patchwork.openembedded.org/patch/170959/
    if $(ls ../layers-under-test/ | grep -q meta-openembedded); then
        pushd ../layers-under-test/
        pushd meta-openembedded
        #git am ~/0001-Move-recipes-with-python-dependencies-into-dynamic-l.patch
        popd
        popd
    fi


####### HERE WE RUN THE 3 tests. LAYERSERIES_COMPAT, LAYERDEPENDS, yocto-check-layer

##### select directory ... jikes is this a mess if we're actually a subdir of a git repo
    if [[ x"" = x"$LAYERSUBDIR" ]] ; then
      #read aw
      ls ../layers-under-test/ | grep -v $LAYERNAME
      grep -q LAYERSERIES_COMPAT ../layers-under-test/$LAYERNAME/conf/layer.conf || export NOLAYERSERIESCOMPAT=true
      $NOLAYERSERIESCOMPAT && echo $i >> $EVALWORKDIR/NOLAYER
      grep -q LAYERDEPENDS ../layers-under-test/$LAYERNAME/conf/layer.conf || export NOLAYERDEPENDS=true
      $NOLAYERDEPENDS && echo $i >> $EVALWORKDIR/NODEPENDS
      set | grep NOLAYER
      bitbake-layers remove-layer $LAYERNAME || true
      $OECORESRCDIR/scripts/yocto-check-layer --dependency ../layers-under-test/ -- ../layers-under-test/$LAYERNAME 2>&1 | tee LOGFILE 2>&1 
      ret=${PIPESTATUS[0]}
    else
      LAYERTOTEST=`find ../layers-under-test/ -type d | grep "meta-.*/$LAYERSUBDIR$" | head -1`
      echo "$LAYERTOTEST"
      grep -q LAYERSERIES_COMPAT $LAYERTOTEST/conf/layer.conf || export NOLAYERSERIESCOMPAT=true
      $NOLAYERSERIESCOMPAT && echo $i >> $EVALWORKDIR/NOLAYER
      grep -q LAYERDEPENDS $LAYERTOTEST/conf/layer.conf || export NOLAYERDEPENDS=true 
      $NOLAYERDEPENDS && echo $i >> $EVALWORKDIR/NODEPENDS
      set | grep NOLAYER
      bitbake-layers remove-layer $LAYERTOTEST || true
      $OECORESRCDIR/scripts/yocto-check-layer --dependency ../layers-under-test/ -- $LAYERTOTEST 2>&1 | tee LOGFILE 2>&1
      ret=${PIPESTATUS[0]}
    fi
    echo "ret: $ret"
    #read aw


    if $NOLAYERSERIESCOMPAT || $NOLAYERDEPENDS || [[ x"0" != x"$ret" ]] ; then
	echo "DO ERROR_EMAIL"
	do_email_header
	do_wiki_header
	$NOLAYERSERIESCOMPAT && do_email_layerseriescompat && do_wiki_layerseriescompat
	$NOLAYERDEPENDS && do_email_layerdepends && do_wiki_layerdepends
      if [[ x"0" != x"$ret" ]] ; then
	echo "Layer not working"
        METADATA=`cat $LAYERFILE | jq -M --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH ' .[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH)'`
	echo "$METADATA"
        ERRORMSG=`cat LOGFILE | grep -A 2 ERROR`
        echo "$ERRORMSG"

	echo "Layername: $LAYERNAME , LayerURL: $LAYERURL, LayerSUBDIR: $LAYERSUBDIR"
	echo "$ERRORMSG" > $TMP/ERROR
	# exception for SPICE
	#grep -q "Nothing PROVIDES 'spice'"         $TMP/ERROR && echo "SKIP DUE TO SPICE!!" && echo "$i" >> $EVALWORKDIR/spice-skip && continue
	#grep -q "Nothing PROVIDES 'spice-protocol'" $TMP/ERROR && echo "SKIP DUE TO SPICE!!" && echo "$i" >> $EVALWORKDIR/spice-skip && continue
	echo "$METADATA" > $TMP/METADATA
	echo "$MAINTAINERS" > $TMP/MAINTAINERS
	[[ x"0" != x"$ret" ]] && do_email_layercheck && do_wiki_layercheck
	popd
	echo "$i" >> $EVALWORKDIR/failed
	echo "$i=y" >> $EVALWORKDIR/layerstested
      fi
      do_email_footer
      do_wikifooter
    else
	echo "Layer working"
	popd
	echo "$i" >> $EVALWORKDIR/working
	echo "$i=y" >> $EVALWORKDIR/layerstested
    fi
    popd
    echo "$i"

done

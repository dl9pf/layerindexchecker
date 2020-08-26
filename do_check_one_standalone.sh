#!/bin/bash
# (C) 2020 dl9pf@gmx.de
# License: GPLv2
# you need bash (not dash!)


echo "Usage: $0 OEBRANCH LAYERNAME"
echo " e.g.: $0 dunfell meta-sdr"

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

NOLAYERSERIESCOMPAT=false
NOLAYERDEPENDS=false
FETCHFAILED=false
LAYERTOCHECK="meta-oe"


[[ -n $1 ]] && OEBRANCH="$1"
[[ -n $2 ]] && LAYERTOCHECK="$2"


do_reportheader(){
cat << EOF >> $EVALWORKDIR/result.txt
== $LAYERNAME ==

The layer $LAYERNAME was tested for:

a) grep LAYERSERIES_COMPAT $LAYERNAME/conf/layer.conf

b) grep LAYERDEPENDS $LAYERNAME/conf/layer.conf

c) run layer check script:  yocto-check-layer (from OE-core repo)


If there are issues found they are listed below:

EOF
}

do_reportlayerseriescompat(){
cat << EOF >> $EVALWORKDIR/result.txt

=== LAYERSERIES_COMPAT missing ===

The layer $LAYERNAME is missing LAYERSERIES_COMPAT in its conf/layer.conf.

EOF
}

do_reportlayerdepends(){
cat << EOF >> $EVALWORKDIR/result.txt

=== LAYERDEPENDS missing ===

The layer $LAYERNAME is missing LAYERDEPENDS in its conf/layer.conf.

EOF
}


do_reportlayercheck(){
cat << EOF >> $EVALWORKDIR/result.txt

=== yocto-check-layer failed ===

- yocto-check-layer did not succeed and the error message was:

<pre>
EOF

echo "$ERRORMSG" | sed -e "s#==.*#----#g" >> $EVALWORKDIR/result.txt

cat << EOF >> $EVALWORKDIR/result.txt
</pre>

==== Full log ====

<pre>

EOF

cat LOGFILE | sed -e "s#==.*#----#g" >> $EVALWORKDIR/result.txt

cat << EOF >> $EVALWORKDIR/result.txt

</pre>

EOF

}


do_wikifooter(){
cat << EOF >> $EVALWORKDIR/result.txt

----

EOF
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
    git reset --hard origin/$BITBAKEBRANCH
    popd
fi

if [[ ! -d $EVALWORKDIR ]] ; then
    mkdir $EVALWORKDIR
fi

cd $EVALWORKDIR

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
for i in $LAYERTOCHECK ; do

    sleep 0.5

    NOLAYERSERIESCOMPAT=false
    NOLAYERDEPENDS=false

    #SKIP BLACKLISTed layers
    if [[ -f $EVALWORKDIR/../BLACKLIST ]] ; then
        grep -q $i $EVALWORKDIR/../BLACKLIST && echo "$i=y" >> $EVALWORKDIR/layerstested && continue
    fi
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
    ls $BBLAYERS_FETCH_DIR
    if [[ $(ls $BBLAYERS_FETCH_DIR | wc -l) -eq 0 ]]; then
	echo "FAILED TO FETCH" 
	echo $LAYERNAME > $EVALWORKDIR/FETCHISSUES 
	do_reportheader
	echo "layerindex-fetch failed" >> $EVALWORKDIR/result.txt
	echo "" >> $EVALWORKDIR/result.txt
	echo "----" >> $EVALWORKDIR/result.txt
	echo "" >> $EVALWORKDIR/result.txt
	echo $i >> $EVALWORKDIR/FETCHFAILED
	do_wikifooter
	echo $i
	continue
    fi

    # HACK#2 fixup meta-oe: aka apply https://patchwork.openembedded.org/patch/170959/
    if $(ls ../layers-under-test/ | grep -q meta-openembedded); then
        pushd ../layers-under-test/
            pushd meta-openembedded
            # not needed atm
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
	do_reportheader
	$NOLAYERSERIESCOMPAT && do_reportlayerseriescompat
	$NOLAYERDEPENDS && do_reportlayerdepends
      if [[ x"0" != x"$ret" ]] ; then
	echo "Layer not working"
        METADATA=`cat $LAYERFILE | jq -M --arg LAYERNAME $LAYERNAME --arg LAYERBRANCH $OECOREBRANCH ' .[] | select(.layer.name==$LAYERNAME) | select(.branch.name==$LAYERBRANCH)'`
	echo "$METADATA"
        ERRORMSG=`cat LOGFILE | grep -A 2 ERROR`
        echo "$ERRORMSG"

	echo "Layername: $LAYERNAME , LayerURL: $LAYERURL, LayerSUBDIR: $LAYERSUBDIR"
	echo "$ERRORMSG" > $TMP/ERROR

	echo "$METADATA" > $TMP/METADATA
	echo "$MAINTAINERS" > $TMP/MAINTAINERS
	[[ x"0" != x"$ret" ]] && do_reportlayercheck
	popd
	echo "$i" >> $EVALWORKDIR/failed
	echo "$i=y" >> $EVALWORKDIR/layerstested
      fi
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

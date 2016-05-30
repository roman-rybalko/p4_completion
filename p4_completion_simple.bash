# Perforce completion by Frank Cusack
#  depot path completion by Andrew May

# Function to handle some of the lists/specs of things from the
# perforce depot.
#
# Arg 1 is the spec type to complete
# Arg 2 is the current input
#
# The typical use is for clientspecs/branchspecs etc. Most of the
# lists from perfoce have the relevant info in the 2nd set of data
# but a few others have it in the first data string.
#
_p4_spec_complete()
{
    local p4spec

    case "$1" in
        counters|users|jobs)
            p4spec="$( p4 $1 | awk 'NF>3 {print $1}' )"
            ;;
        *)
            p4spec="$( p4 $1 | awk 'NF>3 {print $2}' )"
            ;;
    esac

    COMPREPLY=( $( compgen -W "$p4spec" -- $2 ))
}

_p4_depot_path_complete()
{
    local cur p4dirs p4files p4next p4list

    cur="$1"

    p4dirs=$(for x in `p4 dirs $cur\* 2>/dev/null` ; do echo -n "$x/ "; done)
    p4files=$( p4 files $cur\* 2>/dev/null | cut -f1 -d# )
    if [ `echo $p4dirs | wc -w` -eq 1 ] && [ `echo $p4files | wc -w` -eq 0 ]; then
        p4next=$( echo $p4dirs | tr -d [:space:] )
        p4dirs=$(for x in `p4 dirs $p4next\* 2>/dev/null` ; do echo -n "$x/ "; done)
        p4files="$( p4 files $p4next\* 2>/dev/null | cut -f1 -d# )"
        p4list="$p4next $p4dirs $p4files"
    else
        p4list="$p4dirs $p4files"
    fi
    COMPREPLY=( $( compgen -W "$p4list" -- $cur ) )
}

_p4()
{
    local cur prev prev2 p4commands p4filetypes p4globalopts
    local i cmd opts

    COMPREPLY=()
    i=1
    unset cmd
    while [ $i -lt $COMP_CWORD ]; do
        if [ ${COMP_WORDS[$i]:0:1} != "-" ]; then
            cmd=${COMP_WORDS[$i]}
            break
        fi
        i=$(( $i + 1 ))
    done
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    # rename isn't really a command
    #p4commands="$( p4 help commands | awk 'NF>3 {print $1}' )"
    #use a static list of commands to be a bit faster with no server
    p4commands="add admin annotate branch branches change changes changelist changelists \
                client clients counter counters delete depot depots describe diff diff2 dirs edit filelog files \
                fix fixes flush fstat group groups have help info integrate integrated job jobs jobspec label \
                labels labelsync lock logger login logout monitor obliterate opened passwd print protect protects \
                rename reopen resolve resolved revert review reviews set submit sync tag tickets triggers typemap \
                unlock user users verify workspace workspaces where"
    p4filetypes="ctext cxtext ktext kxtext ltext tempobj ubinary \
                 uresource uxbinary xbinary xltext xtempobj xtext \
                 text binary resource"      
    #Global options? from "p4 help usage", -c -C -d....-x
    #plus the unlisted -h -? and -V
    #skipping -v for debug
    p4globalopts="-c -C -d -H -G -L -p -P -s -Q -u -x -V -h"

    if [ -z "${cmd+x}" ]; then
        if [ "${cur:0:1}" = "-" ]; then
            COMPREPLY=( $( compgen -W "$p4globalopts" -- $cur ) )
        else
            COMPREPLY=( $( compgen -W "$p4commands" -- $cur ) )
        fi
        return 0
    fi
    if [ "${cur:0:2}" = "//" ]; then                
        _p4_depot_path_complete "$cur"
        return 0
    fi
    #Try to handle all the flags that need to take arguments.
    #it may depend on the command on what the flag actually does.
    # ie -b is always with a branch?
    # but -t can be a filetype, or template clientspec, or timestamp flag
    # depending on the command
    if [ "${prev:0:1}" = "-" ]; then
        case "$prev" in
            -t)
                case "$cmd" in
                    add|edit|reopen)
                        COMPREPLY=( $( compgen -W "$p4filetypes" \
                                    -- $cur) )
                        return 0
                        ;;
                    client|workspace)
                        _p4_spec_complete clients "$cur"
                        return 0
                        ;;
                    changes|filelog)
                        #nothing to do just date
                        ;;
                    *)
                        ;;
                esac
                ;;
            -c)
                case "$cmd" in
                    add|edit|reopen|deletex)
                        _p4_spec_complete "changes -s pending" "$cur"
                        ;;
                    changes)
                        #this may not be a complete list of clients, since
                        #they may have been deleted
                        _p4_spec_complete "clients -s pending" "$cur"
                        ;;
                esac
                return
                ;;
            -b)
                _p4_spec_complete branches "$cur"
                return
                ;;
            -s)
                #status, for changes
                COMPREPLY=( $( compgen -W "pending submitted" -- $cur ) )                    
                ;;
            -u)
                _p4_sepc_complete "users" "$cur"
                ;;
            *)
                ;;
        esac
    fi
    case "$cmd" in
        add)
            opts="-c -f -n -t"
            ;;
        annotate)
            opts="-a -c -db -dw -i -q"
            ;;
        branch)
            opts="-f -d -o -i"
            ;;
        branches)
            opts="-m"
            ;;
        change|changelist)
            opts="-f -s -d -o -i"
            ;;
        changes|changelists)
            opts="-i -t -l -L -c -m -s -u"
            #-c client -s status -m max count -u user
            ;;
        client|workspace)
            opts="-f -t -d -o -i"
            #-t template
            ;;
        clients|workspaces)
            opts="-m"
            ;;
        counter)
            opts="-f -d"
            #counters output
            ;;
        counters)
            _p4_spec_complete counters "$cur"
            return 0
            ;;
        delete)
            opts="-n -c"
            ;;
        depot)
            opts="-d -o -i"
            ;;
        depots)
            #nothing
            opts=""
            ;;
        describe)
            opts="-dn -dc -ds -du -db -dw -s"
            ;;
        diff)
            # [ -d<flag> -f -m max -sa -sd -se -sl -sr -t ] [ file[rev] ... ]
            opts=""
            ;;
        diff2)
            # [ -d<flag> -q -t -u ] -b branch [ [ file1 ] file2 ]
            opts=""
            ;;
        dirs)
            opts="-C -D -H"
            ;;
        edit)
            opts="-c -n -t"
            ;;
        filelog)
            #-m max all others flaogs
            opts="-i -t -l-L -m"
            ;;
        files)
            opts="-a"
            ;;
        fix)
            opts="-d -s -c"
            _p4_spec_complete jobs "$cur"
            return 0
            ;;
        fixes)
            #-m max -c changelist -j jobname
            opts="-i -m -c -j"
            ;;
        flush)
            opts="-f -n -k"
            ;;
        fstat)
            opts="-m -c -e -Of -Ol -Op -Or -Os -Rc -Rh -Rn -Ro -Rr -Ru"
            ;;
        #skiping group/groups
        #have has nothing
        #info nothing
        integrate)
            opts="-c -d -f -h -i -o -n -r -t -v -Dt -Ds -Di"
            ;;
        integrated)
            opts="-r -b"
            ;;
        help)
            COMPREPLY=( $( compgen -W "simple commands \
            environment filetypes jobview revisions \
            usage views $p4commands" -- $cur ) )
            return 0
            ;;
        tag)
            opts="-b -n -l"
            ;;
        admin)
            COMPREPLY=( $( compgen -W "checkpoint journal stop -z" -- $cur ) )
            return 0
            ;;
        *)
            ;;
    esac
    #if they are trying to use 
    if [ "${cur:0:1}" = "-" ] && [ ! -z "$opts" ]; then
        COMPREPLY=( $( compgen -W "$opts" -- $cur ) )
    fi

    return 0
}
complete -F _p4 -o default p4 g4

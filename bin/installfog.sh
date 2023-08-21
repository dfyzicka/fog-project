#!/bin/bash
#
#Туман - это решение для компьютерной визуализации.
# Copyright (C) 2007 Чак Сиперски и Цзянь Чжан
#
# Эта программа - бесплатное программное обеспечение: вы можете перераспределить его и/или изменить
# это в соответствии с условиями общей публичной лицензии GNU, опубликованной
# Фонд бесплатного программного обеспечения, либо версия 3 лицензии, либо
# любая более поздняя версия.
#
# Эта программа распространяется в надежде, что она будет полезна,
# но без какой -либо гарантии;даже без предполагаемой гарантии
# Торговая способность или пригодность для определенной цели.Увидеть
# GNU General Public Public License для получения более подробной информации.
#
# Вы должны были получить копию общей публичной лицензии GNU
# вместе с этой программой.Если нет, см. <Http://www.gnu.org/licenses/>.
#
bindir=$(dirname $(readlink -f "$BASH_SOURCE"))
cd $bindir
workingdir=$(pwd)

if [[ ! $EUID -eq 0 ]]; then
    echo "Установка тумана должна быть запущена как пользователь root"
    exit 1 # Fail Sudo
fi

which useradd >/dev/null 2>&1
if [[ $? -eq 1 || $(echo $PATH | grep -o "sbin" | wc -l) -lt 2 ]]; then
    echo "Пожалуйста, переключитесь на правильную корневую среду, чтобы запустить установщик!"
    echo "Используйте 'sudo -i' или 'su -' (пропустите «и обратите внимание на дефис в конце"
    echo "команды SU, так как важно загрузить среду Root)."
    exit 1
fi

[[ -z $OS ]] && OS=$(uname -s)
if [[ ! $(echo "$OS" | tr [:upper:] [:lower:]) =~ "linux" ]]; then
    echo "В настоящее время мы не поддерживаем установку в операционных системах, не связанных с лининуксу"
    exit 2 # Fail OS Check
fi 

[[ -z $version ]] && version="$(awk -F\' /"define\('FOG_VERSION'[,](.*)"/'{print $4}' ../packages/web/lib/fog/system.class.php | tr -d '[[:space:]]')"
[[ ! -d ./error_logs/ ]] && mkdir -p ./error_logs >/dev/null 2>&1
error_log=${workingdir}/error_logs/fog_error_${version}.log
timestamp=$(date +%s)
backupconfig=""
. ../lib/common/functions.sh
usage() {
    echo -e "Usage: $0 [-h?dEUuHSCKYXTFA] [-f <filename>] [-N <databasename>]"
    echo -e "\t\t[-D </directory/to/document/root/>] [-c <ssl-path>]"
    echo -e "\t\t[-W <webroot/to/fog/after/docroot/>] [-B </backup/path/>]"
    echo -e "\t\t[-s <192.168.1.10>] [-e <192.168.1.254>] [-b <undionly.kpxe>]"
    echo -e "\t-h -? --help\t\t\tDisplay this info"
    echo -e "\t-o    --oldcopy\t\t\tCopy back old data"
    echo -e "\t-d    --no-defaults\t\tDon't guess defaults"
    echo -e "\t-U    --no-upgrade\t\tDon't attempt to upgrade"
    echo -e "\t-H    --no-htmldoc\t\tNo htmldoc, means no PDFs"
    echo -e "\t-S    --force-https\t\tForce HTTPS for all comunication"
    echo -e "\t-C    --recreate-CA\t\tRecreate the CA Keys"
    echo -e "\t-K    --recreate-keys\t\tRecreate the SSL Keys"
    echo -e "\t-Y -y --autoaccept\t\tAuto accept defaults and install"
    echo -e "\t-f    --file\t\t\tUse different update file"
    echo -e "\t-c    --ssl-path\t\tSpecify the ssl path"
    echo -e "\t               \t\t\t\tdefaults to /opt/fog/snapins/ssl"
    echo -e "\t-D    --docroot\t\t\tSpecify the Apache Docroot for fog"
    echo -e "\t               \t\t\t\tdefaults to OS DocumentRoot"
    echo -e "\t-W    --webroot\t\t\tSpecify the web root url want fog to use"
    echo -e "\t            \t\t\t\t(E.G. http://127.0.0.1/fog,"
    echo -e "\t            \t\t\t\t      http://127.0.0.1/)"
    echo -e "\t            \t\t\t\tDefaults to /fog/"
    echo -e "\t-B    --backuppath\t\tSpecify the backup path"
    echo -e "\t      --uninstall\t\tUninstall FOG"
    echo -e "\t-s    --startrange\t\tDHCP Start range"
    echo -e "\t-e    --endrange\t\tDHCP End range"
    echo -e "\t-b    --bootfile\t\tDHCP Boot file"
    echo -e "\t-E    --no-exportbuild\t\tSkip building nfs file"
    echo -e "\t-X    --exitFail\t\tDo not exit if item fails"
    echo -e "\t-T    --no-tftpbuild\t\tDo not rebuild the tftpd config file"
    echo -e "\t-F    --no-vhost\t\tDo not overwrite vhost file"
    echo -e "\t-A    --arm-support\t\tInstall kernel and initrd for ARM platforms"
    exit 0
}

optspec="h?odEUHSCKYyXxTPFAf:c:-:W:D:B:s:e:b:N:"
while getopts "$optspec" o; do
    case $o in
        -)
            case $OPTARG in
                help)
                    usage
                    exit 0
                    ;;
                uninstall)
                    exit 0
                    ;;
                ssl-path)
                    ssslpath="${OPTARG}"
                    ssslpath="${ssslpath#'/'}"
                    ssslpath="${ssslpath%'/'}"
                    ssslpath="/${ssslpath}/"
                    ;;
                no-vhost)
                    novhost="y"
                    ;;
                no-defaults)
                    guessdefaults=0
                    ;;
                no-upgrade)
                    doupdate=0
                    ;;
                no-htmldoc)
                    signorehtmldoc=1
                    ;;
                force-https)
                    shttpproto="https"
                    ;;
                recreate-keys)
                    srecreateKeys="yes"
                    ;;
                recreate-[Cc][Aa])
                    srecreateCA="yes"
                    ;;
                autoaccept)
                    autoaccept="yes"
                    dbupdate="yes"
                    ;;
                docroot)
                    sdocroot="${OPTARG}"
                    sdocroot="${docroot#'/'}"
                    sdocroot="${docroot%'/'}"
                    sdocroot="/${docroot}/"
                    ;;
                oldcopy)
                    scopybackold=1
                    ;;
                webroot)
                    if [[ $OPTARG != *('/')* ]]; then
                        echo -e "-$OPTARG Нужен путь URL для доступа либо /, или /тумана, например. \ n \ n \ t \ tfor Пример, если вы получите доступ к туману, используя http://127.0.0.1/ без какого -либо следа \ n \ t \ tset the Path to /"
                        usage
                        exit 2
                    fi
                    swebroot="${OPTARG}"
                    swebroot="${webroot#'/'}"
                    swebroot="${webroot%'/'}"
                    ;;
                file)
                    if [[ -f $OPTARG ]]; then
                        fogpriorconfig=$OPTARG
                    else
                        echo "--$OPTARG Требуется файл после"
                        usage
                        exit 3
                    fi
                    ;;
                backuppath)
                    if [[ ! -d $OPTARG ]]; then
                        echo "Путь должен быть существующим каталогом "
                        usage
                        exit 4
                    fi
                    sbackupPath=$OPTARG
                    ;;
                startrange)
                    if [[ $(validip $OPTARG) != 0 ]]; then
                        echo "Неверный IP прошел"
                        usage
                        exit 5
                    fi
                    sstartrange=$OPTARG
                    dodhcp="Y"
                    bldhcp=1
                    ;;
                endrange)
                    if [[ $(validip $OPTARG) != 0 ]]; then
                        echo "Неверный IP прошел"
                        usage
                        exit 6
                    fi
                    sendrange=$OPTARG
                    dodhcp="Y"
                    bldhcp=1
                    ;;
                no-exportbuild)
                    sblexports=0
                    ;;
                exitFail)
                    sexitFail=1
                    ;;
                no-tftpbuild)
                    snoTftpBuild="true"
                    ;;
                arm-support)
                    sarmsupport=1
                    ;;
                *)
                    if [[ $OPTERR == 1 && ${optspec:0:1} != : ]]; then
                        echo "Неизвестный вариант: --${OPTARG}"
                        usage
                        exit 7
                    fi
                    ;;
            esac
            ;;
        h|'?')
            usage
            exit 0
            ;;
        o)
            scopybackold=1
            ;;
        c)
            ssslpath="${OPTARG}"
            ssslpath="${ssslpath#'/'}"
            ssslpath="${ssslpath%'/'}"
            ssslpath="/${ssslpath}/"
            ;;
        d)
            guessdefaults=0
            ;;
        U)
            doupdate=0
            ;;
        H)
            signorehtmldoc=1
            ;;
        S)
            shttpproto="https"
            ;;
        K)
            srecreateKeys="yes"
            ;;
        C)
            srecreateCA="yes"
            ;;
        [yY])
            autoaccept="yes"
            dbupdate="yes"
            ;;
        F)
            novhost="y"
            ;;
        D)
            sdocroot=$OPTARG
            sdocroot=${docroot#'/'}
            sdocroot=${docroot%'/'}
            sdocroot=/${docroot}/
            ;;
        W)
            if [[ $OPTARG != *('/')* ]]; then
                echo -e "-$OPTARG Нужен путь URL для доступа либо /, или /тумана, например. \ n \ n \ t \ tfor Пример, если вы получите доступ к туману, используя http://127.0.0.1/ без какого -либо следа \ n \ t \ tset the Path to /"
                usage
                exit 2
            fi
            swebroot=$OPTARG
            swebroot=${webroot#'/'}
            swebroot=${webroot%'/'}
            ;;
        f)
            if [[ ! -f $OPTARG ]]; then
                echo "-$OPTARG Требуется файл, которому нужно следовать"
                usage
                exit 3
            fi
            fogpriorconfig=$OPTARG
            ;;
        B)
            if [[ ! -d $OPTARG ]]; then
                echo "Путь должен быть существующим каталогом"
                usage
                exit 4
            fi
            sbackupPath=$OPTARG
            ;;
        s)
            if [[ $(validip $OPTARG) != 0 ]]; then
                echo "Неверный IP прошел"
                usage
                exit 5
            fi
            sstartrange=$OPTARG
            dodhcp="Y"
            bldhcp=1
            ;;
        e)
            if [[ $(validip $OPTARG) != 0 ]]; then
                echo "Неверный IP прошел"
                usage
                exit 6
            fi
            sendrange=$OPTARG
            dodhcp="Y"
            bldhcp=1
            ;;
        E)
            sblexports=0
            ;;
        X)
            exitFail=1
            ;;
        T)
            snoTftpBuild="true"
            ;;
        A)
            sarmsupport=1
            ;;
        N)
            if [[ -z $OPTARG ]]; then
                echo "Укажите имя базы данных"
                usage
                exit 4
            fi
            smysqldbname=$OPTARG
            ;;
        :)
            echo "Вариант -$OPTARG требует значенияe"
            usage
            exit 8
            ;;
        *)
            if [[ $OPTERR == 1 && ${optspec:0:1} != : ]]; then
                echo "Неизвестный вариант: -$OPTARG"
                usage
                exit 7
            fi
            ;;
    esac
done

if [[ -f /etc/os-release ]]; then
    [[ -z $linuxReleaseName ]] && linuxReleaseName=$(sed -n 's/^NAME=\(.*\)/\1/p' /etc/os-release | tr -d '"')
    [[ -z $OSVersion ]] && OSVersion=$(sed -n 's/^VERSION_ID=\([^.]*\).*/\1/p' /etc/os-release | tr -d '"')
elif [[ -f /etc/redhat-release ]]; then
    [[ -z $linuxReleaseName ]] && linuxReleaseName=$(cat /etc/redhat-release | awk '{print $1}')
    [[ -z $OSVersion ]] && OSVersion=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*// | awk -F. '{print $1}')
elif [[ -f /etc/debian_version ]]; then
    [[ -z $linuxReleaseName ]] && linuxReleaseName='Debian'
    [[ -z $OSVersion ]] && OSVersion=$(cat /etc/debian_version)
fi

linuxReleaseName_lower=$(echo "$linuxReleaseName" | tr [:upper:] [:lower:])

echo "Installing LSB_Release as needed"
dots "Attempting to get release information"
command -v lsb_release >$error_log 2>&1
exitcode=$?
if [[ ! $exitcode -eq 0 ]]; then
    case $linuxReleaseName_lower in
        *bian*|*ubuntu*|*mint*)
            apt-get -yq install lsb-release >>$error_log 2>&1
            ;;
        *centos*|*red*hat*|*fedora*|*alma*|*rocky*)
            command -v dnf >>$error_log 2>&1
            exitcode=$?
            case $exitcode in
                0)
                    dnf -y install redhat-lsb-core >>$error_log 2>&1
                    ;;
                *)
                    yum -y install redhat-lsb-core >>$error_log 2>&1
                    ;;
            esac
            ;;
        *arch*)
            pacman -Sy --noconfirm lsb-release >>$error_log 2>&1
            ;;
    esac
fi
[[ -z $OSVersion ]] && OSVersion=$(lsb_release -rs| awk -F'.' '{print $1}')
[[ -z $OSMinorVersion ]] && OSMinorVersion=$(lsb_release -rs| awk -F'.' '{print $2}')
echo "Done"
. ../lib/common/config.sh
[[ -z $dnsaddress ]] && dnsaddress=""
[[ -z $username ]] && username=""
[[ -z $password ]] && password=""
[[ -z $osid ]] && osid=""
[[ -z $osname ]] && osname=""
[[ -z $dodhcp ]] && dodhcp=""
[[ -z $bldhcp ]] && bldhcp=""
[[ -z $installtype ]] && installtype=""
[[ -z $interface ]] && interface=""
[[ -z $ipaddress ]] && ipaddress=""
[[ -z $hostname ]] && hostname=""
[[ -z $routeraddress ]] && routeraddress=""
[[ -z $plainrouter ]] && plainrouter=""
[[ -z $blexports ]] && blexports=1
[[ -z $installlang ]] && installlang=0
[[ -z $bluseralreadyexists ]] && bluseralreadyexists=0
[[ -z $guessdefaults ]] && guessdefaults=1
[[ -z $doupdate ]] && doupdate=1
[[ -z $ignorehtmldoc ]] && ignorehtmldoc=0
[[ -z $httpproto ]] && httpproto="http"
[[ -z $armsupport ]] && armsupport=0
[[ -z $mysqldbname ]] && mysqldbname="fog"
[[ -z $tftpAdvOpts ]] && tftpAdvOpts=""
[[ -z $fogpriorconfig ]] && fogpriorconfig="$fogprogramdir/.fogsettings"
#clearScreen
if [[ -z $* || $* != +(-h|-?|--help|--uninstall) ]]; then
    echo > "$workingdir/error_logs/foginstall.log"
    exec &> >(tee -a "$workingdir/error_logs/foginstall.log")
fi
displayBanner
echo -e "   Versio:n $version Installer/Updater\n"
checkSELinux
checkFirewall
case $doupdate in
    1)
        if [[ -f $fogpriorconfig ]]; then
            echo -e "\n *Найдены настройки тумана из предыдущей установки по адресу: $fogprogramdir/.fogsettings\n"
            echo -n " * Выполнение обновления с использованием этих настроек"
            . "$fogpriorconfig"
            doOSSpecificIncludes
            [[ -n $sblexports ]] && blexports=$sblexports
            [[ -n $snoTftpBuild ]] && noTftpBuild=$snoTftpBuild
            [[ -n $sbackupPath ]] && backupPath=$sbackupPath
            [[ -n $swebroot ]] && webroot=$swebroot
            [[ -n $sdocroot ]] && docroot=$sdocroot
            [[ -n $signorehtmldoc ]] && ignorehtmldoc=$signorehtmldoc
            [[ -n $scopybackold ]] && copybackold=$scopybackold
        fi
        ;;
    *)
        echo -e "\n * Установщик тумана не будет пытаться обновить с\n   Предыдущая версия тумана."
        ;;
esac
# evaluation of command line options
[[ -n $shttpproto ]] && httpproto=$shttpproto
[[ -n $sstartrange ]] && startrange=$sstartrange
[[ -n $sendrange ]] && endrange=$sendrange
[[ -n $ssslpath ]] && sslpath=$ssslpath
[[ -n $srecreateCA ]] && recreateCA=$srecreateCA
[[ -n $srecreateKeys ]] && recreateKeys=$srecreateKeys
[[ -n $sarmsupport ]] && armsupport=$sarmsupport

[[ -f $fogpriorconfig ]] && grep -l webroot $fogpriorconfig >>$error_log 2>&1
case $? in
    0)
        if [[ -n $webroot ]]; then
            webroot=${webroot#'/'}
            webroot=${webroot%'/'}
        fi
        [[ -z $webroot ]] && webroot="/" || webroot="/${webroot}/"
        ;;
    *)
        [[ -z $webroot ]] && webroot="/fog/"
        ;;
esac
if [[ -z $backupPath ]]; then
    backupPath="/home/"
    backupPath="${backupPath%'/'}"
    backupPath="${backupPath#'/'}"
    backupPath="/$backupPath/"
fi
[[ -n $smysqldbname ]] && mysqldbname=$smysqldbname
[[ ! $doupdate -eq 1 || ! $fogupdateloaded -eq 1 ]] && . ../lib/common/input.sh
# ask user input for newly added options like hostname etc.
. ../lib/common/newinput.sh
echo
echo "   ######################################################################"
echo "   #    У тумана теперь есть все, что ему нужно для этой настройки, но, пожалуйста    #"
echo "   #   Поймите, что этот скрипт перезаписывает любую настройку, которые вы можете  #"
echo "   #   Настройка для таких услуг, как DHCP, Apache, PXE, TFTP и NFS.   #"
echo "   ######################################################################"
echo "   #     Не рекомендуется устанавливать это на производственную систему #"
echo "   #        Поскольку этот скрипт изменяет многие из настроек вашей системы.     #"
echo "   ######################################################################"
echo "   #          Этот скрипт должен запускать пользователем root.          #"
echo "   #      Он будет подготовить бег с Sudo, если root не установлен    #"
echo "   ######################################################################"
echo "   #           Пожалуйста, смотрите нашу вики для получения дополнительной информации по адресу:         #"
echo "   ######################################################################"
echo "   #             https://wiki.fogproject.org/wiki/index.php             #"
echo "   ######################################################################"
echo
echo " * Вот настройки, которые туман будет использовать:"
echo " * Базовый Linux: $osname"
echo " * Обнаружено распределение Linux: $linuxReleaseName"
echo " * Интерфейс: $interface"
echo " * IP-адрес сервера: $ipaddress"
echo " * Маска подсети сервера: $submask"
echo " * Имя хоста: $hostname"
case $installtype in
    N)
        echo " * Тип установки: нормальный сервер"
        echo -n " * Интернационализация: "
        case $installlang in
            1)
                echo "Yes"
                ;;
            *)
                echo "No"
                ;;
        esac
        echo " * Место хранения изображений: $storageLocation"
        case $bldhcp in
            1)
                echo " * Используя FOG DHCP: Yes"
                echo " *Адрес маршрутизатора DHCP: $plainrouter"
                ;;
            *)
                echo " *Используя FOG DHCP: No"
                echo " * DHCP не будет настроен, но вы должны настроить свой"
                echo " | Текущий сервер DHCP для использования FOG для сервисов PXE."
                echo
                echo " * На сервере Linux DHCP вы должны установить: Next-Server и Filename"
                echo
                echo " * На сервере Windows DHCP вы должны установить параметры 066 и 067"
                echo
                echo " * Вариант 066/Next-Server-это IP на FOG-сервере: (e.g. $ipaddress)"
                echo " * Вариант 067/Имя файла - BootFile: (например, unionly.kkpxe или snponly.efi)"
                ;;
        esac
        ;;
    S)
        echo " * Тип установки: Storage Node"
        echo " * Node IP Address: $ipaddress"
        echo " * MySQL Database Host: $snmysqlhost"
        echo " * MySQL Database User: $snmysqluser"
        ;;
esac
echo -n " * Отправить имя ОС, версию ОС и версия тумана: "
case $sendreports in
    Y)
        echo "Yes"
        ;;
    *)
        echo "No"
        ;;
esac
echo
while [[ -z $blGo ]]; do
    echo
    [[ -n $autoaccept ]] && blGo="y"
    if [[ -z $autoaccept ]]; then
        echo -n " * Вы уверены, что хотите продолжить(Y/N) "
        read blGo
    fi
    echo
    case $blGo in
        [Yy]|[Yy][Ee][Ss])
            echo " * Установка началась"
            echo
            checkInternetConnection
            if [[ $ignorehtmldoc -eq 1 ]]; then
                [[ -z $newpackagelist ]] && newpackagelist=""
                newpackagelist=( "${packages[@]/$htmldoc}" )
                packages="$(echo $newpackagelist)"
            fi
            if [[ $bldhcp == 0 ]]; then
                [[ -z $newpackagelist ]] && newpackagelist=""
                newpackagelist=( "${packages[@]/$dhcpname}" )
                packages="$(echo $newpackagelist)"
            fi
            case $installtype in
                [Ss])
                    packages=$(echo $packages | sed -e 's/[-a-zA-Z]*dhcp[-a-zA-Z]*//g')
                    ;;
            esac
            installPackages
            echo
            echo " *Подтверждение установки пакета "
            echo
            confirmPackageInstallation
            echo
            echo " * Настройка сервисов"
            echo
            if [[ -z $storageLocation ]]; then
                case $autoaccept in
                    [Yy]|[Yy][Ee][Ss])
                        storageLocation="/images"
                        ;;
                    *)
                        echo
                        echo -n " *Какое местоположение хранилища для вашего каталога изображений? (/images) "
                        read storageLocation
                        [[ -z $storageLocation ]] && storageLocation="/images"
                        while [[ ! -d $storageLocation && $storageLocation != "/images" ]]; do
                            echo -n " * Пожалуйста, введите действительный каталог для вашего места хранения (/images) "
                            read storageLocation
                            [[ -z $storageLocation ]] && storageLocation="/images"
                        done
                        ;;
                esac
            fi
            configureUsers
            case $installtype in
                [Ss])
                    checkDatabaseConnection
                    backupReports
                    configureMinHttpd
                    configureStorage
                    configureDHCP
                    configureTFTPandPXE
                    configureFTP
                    configureSnapins
                    configureUDPCast
                    installInitScript
                    installFOGServices
                    configureFOGService
                    configureNFS
                    writeUpdateFile
                    linkOptFogDir
                    if [[ $bluseralreadyexists == 1 ]]; then
                        echo
                        echo "\n * Обновление завершено\n"
                        echo
                    else
                        registerStorageNode
                        updateStorageNodeCredentials
                        [[ -n $snmysqlhost ]] && fogserver=$snmysqlhost || fogserver="fog-server"
                        echo
                        echo " * Настройка завершена"
                        echo
                        echo
                        echo " * Вам все еще нужно настроить этот узел в управлении туманом "
                        echo " | портал.Вам понадобится перечислено имя пользователя и пароль"
                        echo " | below."
                        echo
                        echo " * Management Server URL:"
                        echo "   ${httpproto}://${fogserver}${webroot}"
                        echo
                        echo "   Вам это понадобится, запишите это!"
                        echo "   IP Address:          $ipaddress"
                        echo "   Interface:           $interface"
                        echo "   Management Username: $username"
                        echo "   Management Password: $password"
                        echo
                    fi
                    ;;
                [Nn])
                    configureMySql
                    backupReports
                    configureHttpd
                    backupDB
                    updateDB
                    configureStorage
                    configureDHCP
                    configureTFTPandPXE
                    configureFTP
                    configureSnapins
                    configureUDPCast
                    installInitScript
                    installFOGServices
                    configureFOGService
                    configureNFS
                    writeUpdateFile
                    linkOptFogDir
                    updateStorageNodeCredentials
                    setupFogReporting
                    echo
                    echo " * Настройка завершена"
                    echo
                    echo "Теперь вы можете войти в портал управления FOG, используя"
                    echo "информация, перечисленная ниже."
                    echo "это только в том случае, если это первая установка".
                    echo
                    echo "   Это можно сделать, открыв веб -браузер и поступив на:"
                    echo
                    echo "   ${httpproto}://${ipaddress}${webroot}management"
                    echo
                    echo "   Информация пользователя по умолчанию"
                    echo "   Username: fog"
                    echo "   Password: password"
                    echo
                    ;;
            esac
            [[ -d $webdirdest/maintenance ]] && rm -rf $webdirdest/maintenance
            ;;
        [Nn]|[Nn][Oo])
            echo " * Установщик FOG выходит по запросу пользователя"
            exit 0
            ;;
        *)
            echo
            echo " * Извините, ответ не признан"
            echo
            exit 1
            ;;
    esac
done
if [[ -n "${backupconfig}" ]]; then
    echo " * Изменены конфигурации:"
    echo
    echo "   Установщик FOG изменил файлы конфигурации и создал"
    echo "   Следующие файлы резервного копирования из ваших исходных файлов:"
    for conffile in ${backupconfig}; do
        echo "   * ${conffile} <=> ${conffile}.${timestamp}"
    done
    echo
fi

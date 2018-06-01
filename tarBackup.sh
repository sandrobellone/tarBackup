#!/bin/bash
#tarBackup.sh
#versione 0.02 del 16 Dicembre 2017
#Copyright 2017 Sandro Bellone
#Rilasciato secondo i termini della Licenza Pubblica Generica GNU
#Esegue il backup di $ORIG in $DEST

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

T_INIZIO=`date +%s%N`
MY_HOME="${0%/*}" #parameter expansion
DEBUG=0
LOGGING=0
DATA=`date +%y%m%d_%H%M%S`
NOME_BACK=""

#Funzione stampa
function _stampa {
  if [ $LOGGING -eq 1 ]; then echo $@ | tee -a $MY_HOME/tarBackup_log.txt
  else echo $@
  fi
}

#Funzione uscita
function _esci {
  T_FINE=`date +%s%N`
  T_DIFF=$((T_FINE - T_INIZIO))
  _stampa "Tempo impiegato: $((T_DIFF/1000000000))sec\
           $((T_DIFF/1000000%1000))msec"
  if [ $DEBUG -eq 1 ]; then
    _stampa "-->"cod.uscita=$1
  fi
  exit $1
}

#Controlla l'esistenza delle cartelle di origine e destinazione
function _check_exist {
  _stampa -n "controllo esistenza cartelle  ... "
  if [ ! -d "$ORIG" ]; then
    _stampa 'origine non esiste'
    _esci 1
  elif [ ! -d "$DEST" ]; then
    _stampa 'destinazione non esiste'
    _esci 1
  fi
  _stampa 'ok'
}

function _controllo_variazioni {
  ULTIMO_BACKUP=`ls -c1 $DEST/$NOME_BACK*{_full,_inc}*|head -n 1`
  _stampa "Controllo variazioni rispetto all'ultimo backup... "
  /bin/tar -C "$ORIG/.."\
           -df $ULTIMO_BACKUP "$NOME_CARTELLA_ORIG"\
		   --exclude=$NOME_BACK*{_full,_inc,_list}*
  if [ $? -eq 0 ]; then
    _stampa "Nessuna variazione rispetto all'ultimo backup"
    _esci 0
  fi
}

#Funzione backup, lancia il comando tar e fa una copia del file lista
function _backup {
  if [ $DEBUG -eq 1 ]; then
    _stampa -e '\n-->'/bin/tar -C "$ORIG/.."\
           --listed-incremental=$NOME_ULTIMO_FILE_LISTA\
           -czf $1 "$NOME_CARTELLA_ORIG"\
		   --exclude=$NOME_BACK*{_full,_inc,_list}*
  fi
  /bin/tar -C "$ORIG/.."\
           --listed-incremental=$NOME_ULTIMO_FILE_LISTA\
           -czf $1 "$NOME_CARTELLA_ORIG"\
		   --exclude=$NOME_BACK*{_full,_inc,_list}*
  _stampa "Cod. uscita tar: " $?
  cp $NOME_ULTIMO_FILE_LISTA $NOME_FILE_LISTA
}

function _incrementale {
  NOME_FILE_INC=$DEST"/"$NOME_BACK"_"$DATA"_inc.tar.gz"
  _backup $NOME_FILE_INC
}

function _completo {
  NOME_FILE_COMPL=$DEST"/"$NOME_BACK"_"$DATA"_full.tar.gz"
  rm -f $NOME_ULTIMO_FILE_LISTA
  _backup $NOME_FILE_COMPL
}

function _controlla_log_file {
    if [ ! -e "$MY_HOME/tarBackup_log.txt" ]; then touch $MY_HOME/tarBackup_log.txt; fi
    DIM_LOG_FILE=`du $MY_HOME/tarBackup_log.txt |cut -f 1`
    if [ $DEBUG -eq 1 ]; then
      _stampa "-->Dimensione log file: $DIM_LOG_FILE kb"
    fi
    if [ $DIM_LOG_FILE -gt 8  ]; then
      _stampa "Compressione log file..."
      NUM_LOG_FILE=`ls -c1 $MY_HOME/tarBackup_log*.tar.gz 2> /dev/null | wc -l`
      if [ $DEBUG -eq 1 ]; then
          _stampa "-->NUM_LOG_FILE=: $NUM_LOG_FILE"
      fi
      /bin/tar -C "$MY_HOME" -czf "$MY_HOME/tarBackup_log_$NUM_LOG_FILE.tar.gz" tarBackup_log.txt
      if [ $? -eq 0 ]; then
         rm -f $MY_HOME/tarBackup_log.txt
      fi
    fi
}

while getopts "hdln:" opt; do
  case $opt in
    n)
	  NOME_BACK=$OPTARG
      _stampa "NOME_BACK=$OPTARG"
      ;;
    h)
	  cat $MY_HOME/tarBackup_Readme.txt
      _esci 0
      ;;
	d)
	  _stampa "-->Debug attivato"
	  DEBUG=1
	  ;;
	l)
	  echo "-->Logging attivato"
	  LOGGING=1
	  echo "---------------------------" >> $MY_HOME/tarBackup_log.txt
	  echo "-->" inizio Logging - `date` >> $MY_HOME/tarBackup_log.txt
	  _controlla_log_file
          ;;
    \?)
      _stampa "Opzione non valida: -$OPTARG" >&2
      _esci 1
      ;;
  esac
done
if [ -z $NOME_BACK ]; then
   _stampa "Errore, indicare il nome di un backup"
   _esci 1
fi
source "$MY_HOME/$NOME_BACK.conf"
NOME_CARTELLA_ORIG=`echo $ORIG| tr '/' '\n'|tail -n1`
NOME_FILE_LISTA=$DEST"/"$NOME_BACK"_"$DATA"_list".idx
NOME_ULTIMO_FILE_LISTA=$DEST"/"$NOME_BACK"_list".idx
_check_exist
if [ $DEBUG -eq 1 ]; then
  _stampa "-->MY_HOME="$MY_HOME
  _stampa "-->NOME_BACK="$NOME_BACK
#  _stampa "-->NOME_FILE_COMPL"=$NOME_FILE_COMPL
#  _stampa "-->NOME_FILE_INC"=$NOME_FILE_INC
fi
_controllo_variazioni
NBACK_COMPL=`ls -X1 $DEST/$NOME_BACK* 2> /dev/null |grep "_full."|wc -l`
NBACK_INCR=`ls -rX1 $DEST/$NOME_BACK*{full,inc}* 2> /dev/null |\
            grep -m 1 -n "_full."|cut -d':' -f1`
if [ -z $NBACK_INCR ]; then
   NBACK_INCR=0
else
  ((NBACK_INCR -= 1))
fi
_stampa Rilevati $NBACK_COMPL backup completi e $NBACK_INCR incrementali
if [ $NBACK_COMPL -gt $NMAX_BACK_COMPL ]; then
  _stampa 'Troppi backup interi, i vecchi backup saranno cancellati'
  OLDEST=`ls -c1 $DEST/$NOME_BACK*{_full,_inc,_list}*|\
          grep -m $NMAX_BACK_COMPL "_full"|tail -n 1`
  if [ $DEBUG -eq 1 ]; then echo OLDEST=$OLDEST; fi
  for file in `ls -c1 $DEST/$NOME_BACK*{_full,_inc,_list}*`
  do
    if [[ $file < $OLDEST ]]; then
	  _stampa ELIMINO: $file
	  rm $file
	fi
  done
fi
if [ $NBACK_COMPL -eq 0 ]; then
  _stampa -n 'Non ci sono backup interi, procedo ad un backup intero ... '
  _completo
elif [ $NBACK_INCR -ge $NMAX_BACK_INCR ]; then
  _stampa -n 'Troppi backup incrementali, procedo ad un backup intero ... '
  _completo
else
  _stampa -n 'Inizio backup incrementale ... '
  _incrementale
fi
_stampa ok
_esci 0

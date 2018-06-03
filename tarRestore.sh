#!/bin/bash
#tarRestore.sh
#versione 0.02 del 3 Giugno 2018
#Copyright 2017 2018 Sandro Bellone
#Rilasciato secondo i termini della Licenza Pubblica Generica GNU
#Esegue il restore di $DEST in $RIPR

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
MY_HOME="${0%/*}" #parameter expansion - espande l'argomento 0 (che contiene
               #percorso e nome del programma) e ne mantiene solo il percorso
DEBUG=0
LOGGING=0
DATA=`date +%y%m%d_%H%M%S`
NOME_BACK=""
DIM_MAX_LOG_FILE=100 #Limite dimensione log file, in kb
LOG_FILE=tarRestore_log.txt

#Funzione stampa
function _stampa
{
  if [ $LOGGING -eq 1 ]; then echo $@ | tee -a $MY_HOME/$LOG_FILE
  else echo $@
  fi
}

#Funzione uscita
function _esci
{
  T_FINE=`date +%s%N`
  T_DIFF=$((T_FINE - T_INIZIO))
  _stampa "Tempo impiegato: $((T_DIFF/1000000000))sec\
           $((T_DIFF/1000000%1000))msec"
  if [ $DEBUG -eq 1 ]; then
    _stampa "-->"cod.uscita=$1
  fi
  exit $1
}

#Controlla l'esistenza delle cartelle di backup e di ripristino
function _check_exist
{
  _stampa -n "controllo esistenza cartelle  ... "
  if [ ! -d $DEST ]; then
    _stampa 'Cartella di backup non esiste'
    _esci 1
  elif [ ! -d $RIPR ]; then
    _stampa 'Cartella di ripristino non esiste'
    _esci 1
  fi
  _stampa 'ok'
}

#Funzione restore, lancia il comando tar
function _restore
{
  NOME_CARTELLA_DEST=`echo $DEST| tr '/' '\n'|tail -n1`
  if [ $DEBUG -eq 1 ]; then
    _stampa -e '\n-->'/bin/tar --extract -z -C "$RIPR" \
           --listed-incremental=/dev/null \
           --file $1
  fi
  /bin/tar --extract -z -C "$RIPR" \
           --listed-incremental=/dev/null \
           --file $1
}

function _controlla_log_file {
    if [ ! -e "$MY_HOME/$LOG_FILE" ]; then touch $MY_HOME/$LOG_FILE; fi
    DIM_LOG_FILE=`du $MY_HOME/$LOG_FILE |cut -f 1`
    if [ $DEBUG -eq 1 ]; then
      _stampa "-->Dimensione log file: $DIM_LOG_FILE kb"
    fi
    if [ $DIM_LOG_FILE -gt $DIM_MAX_LOG_FILE  ]; then
      _stampa "Compressione log file..."
      NUM_LOG_FILE=`ls -c1 $MY_HOME/tarRestore_log*.tar.gz 2> /dev/null | wc -l`
      if [ $DEBUG -eq 1 ]; then
          _stampa "-->NUM_LOG_FILE=: $NUM_LOG_FILE"
      fi
      /bin/tar -C "$MY_HOME" -czf "$MY_HOME/tarRestore_log_$NUM_LOG_FILE.tar.gz" $LOG_FILE
      if [ $? -eq 0 ]; then
         rm -f $MY_HOME/$LOG_FILE
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
	  cat $MY_HOME/tarRestore_Readme.txt
      _esci 0
      ;;
	d)
	  _stampa "-->Debug attivato"
	  DEBUG=1
	  ;;
	l)
	  echo "-->Logging attivato"
	  LOGGING=1
	  echo "---------------------------" >> $MY_HOME/$LOG_FILE
	  echo "-->" inizio Logging - `date` >> $MY_HOME/$LOG_FILE
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
_check_exist
if [ $DEBUG -eq 1 ]; then
  _stampa "-->MY_HOME="$MY_HOME
  _stampa "-->NOME_BACK="$NOME_BACK
fi

NEWEST=`ls -c1 $DEST/$NOME_BACK*_full* 2> /dev/null |head -n 1 `
if [ -z $NEWEST ]; then
  _stampa Non ci sono backup interi
  _esci
fi

if [ $DEBUG -eq 1 ]; then _stampa "-->NEWEST=$NEWEST"; fi
for file in `ls -x1 $DEST/$NOME_BACK*{_full,_inc}*`
  do
    if [[ ( $file > $NEWEST ) || ( $file = $NEWEST ) ]]; then
	     _stampa Ripristino: $file
       _restore $file
	  fi
  done

_stampa ok
_esci 0

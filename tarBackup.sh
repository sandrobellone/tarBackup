#!/bin/bash
#tarBackup.sh
#versione 0.10 del 02 Ottobre 2017
#Copyright 2017 Sandro Bellone
#Rilasciato secondo i termini della Licenza Pubblica Generica GNU
#Esegue il backup di $ORIGINE in $DESTINAZIONE

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
NOME_BACKUP=prove2
ORIGINE=/home/sandro
DESTINAZIONE=/home/sandro/backup
NUMERO_MAX_BACKUP_COMPLETI=3
NUMERO_MAX_BACKUP_INCREMENTALI=5
CARTELLA_CORRENTE="${0%/*}" #parameter expansion
DEBUG=0
LOGGING=0

DATA=`date +%y%m%d_%H%M%S`
NOME_FILE_INC=$DESTINAZIONE"/"$NOME_BACKUP"_"$DATA"_inc.tar.gz"
NOME_FILE_COMPL=$DESTINAZIONE"/"$NOME_BACKUP"_"$DATA"_full.tar.gz"
NOME_FILE_LISTA=$DESTINAZIONE"/"$NOME_BACKUP"_"$DATA"_list".idx
NOME_ULTIMO_FILE_LISTA=$DESTINAZIONE"/"$NOME_BACKUP"_list".idx


#Funzione stampa
function _stampa
{
  echo $@ | tee -a $CARTELLA_CORRENTE/tarBackup_log.txt
}

#Funzione uscita
function _esci
{
  T_FINE=`date +%s%N`
  T_DIFF=$((T_FINE - T_INIZIO))
  _stampa "Tempo impiegato: $((T_DIFF/1000000000))sec$((T_DIFF/1000000%1000))msec"
  if [ $DEBUG -eq 1 ]; then
    _stampa "-->"cod.uscita=$1
  fi
  exit $1
}

#Controlla l'esistenza delle cartelle di origine e destinazione
function _check_exist
{
  _stampa -n "controllo esistenza cartelle  ... "
  if [ ! -d $ORIGINE ]; then
    _stampa 'origine non esiste'
    _esci 1
  elif [ ! -d $DESTINAZIONE ]; then
    _stampa 'destinazione non esiste'
    _esci 1
  fi
  _stampa 'ok'
}

#Funzione backup, lancia il comando tar e fa una copia del file lista
function _backup
{
  NOME_CARTELLA_ORIGINE=`echo $ORIGINE| tr '/' '\n'|tail -n1`
  if [ $DEBUG -eq 1 ]; then
    _stampa -e '\n-->'/bin/tar -C $ORIGINE/..\
           --listed-incremental=$NOME_FILE_LISTA\
           -czf $1 $NOME_CARTELLA_ORIGINE\
		   --exclude=$NOME_BACKUP*{_full,_inc,_list}*
  fi
  /bin/tar -C $ORIGINE/..\
           --listed-incremental=$NOME_FILE_LISTA\
           -czf $1 $NOME_CARTELLA_ORIGINE\
		   --exclude=$NOME_BACKUP*{_full,_inc,_list}*
  cp $NOME_FILE_LISTA $NOME_ULTIMO_FILE_LISTA
}

function _incrementale
{
  _backup $NOME_FILE_INC
}

function _completo
{
  rm -f $NOME_FILE_LISTA
  _backup $NOME_FILE_COMPL
}

while getopts "hdl" opt; do
  case $opt in
    h)
	  cat $CARTELLA_CORRENTE/tarBackup_Readme.txt
      _esci 0
      ;;
	d)
	  _stampa "-->Debug attivato"
	  DEBUG=1
	  ;;
	l)
	  echo "-->Logging attivato"
	  LOGGING=1
	  echo "---------------------------" >> $CARTELLA_CORRENTE/tarBackup_log.txt
	  echo "-->" inizio Logging - `date` >> $CARTELLA_CORRENTE/tarBackup_log.txt
	  ;;
    \?)
      _stampa "Opzione non valida: -$OPTARG" >&2
      _esci 1
      ;;
  esac
done
if [ $LOGGING -eq 0 ]; then $CARTELLA_CORRENTE/tarBackup_log.txt=/dev/null; fi
_check_exist
if [ $DEBUG -eq 1 ]; then
  _stampa "-->CARTELLA_CORRENTE="$CARTELLA_CORRENTE
  _stampa "-->NOME_BACKUP="$NOME_BACKUP
  _stampa "-->NOME_FILE_COMPL"=$NOME_FILE_COMPL
  _stampa "-->NOME_FILE_INC"=$NOME_FILE_INC
fi
NUMERO_BACKUP_COMPLETI=`ls -X1 $DESTINAZIONE/$NOME_BACKUP* 2> /dev/null |grep "_full."|wc -l`
NUMERO_BACKUP_INC=`ls -rX1 $DESTINAZIONE/$NOME_BACKUP*{full,inc}* 2> /dev/null | grep -m 1 -n "_full."|cut -d':' -f1`
if [ -z $NUMERO_BACKUP_INC ]; then
   NUMERO_BACKUP_INC=0
else
  ((NUMERO_BACKUP_INC -= 1))
fi
_stampa Rilevati $NUMERO_BACKUP_COMPLETI backup completi e $NUMERO_BACKUP_INC incrementali
if [ $NUMERO_BACKUP_COMPLETI -gt $NUMERO_MAX_BACKUP_COMPLETI ]; then
  _stampa 'Troppi backup interi, procedo alla cancellazione dei vecchi backup?'
  OLDEST=`ls -c1 $DESTINAZIONE/$NOME_BACKUP*{_full,_inc,_list}*|grep -m $NUMERO_MAX_BACKUP_COMPLETI "_full"|tail -n 1`
  if [ $DEBUG -eq 1 ]; then echo OLDEST=$OLDEST; fi
  for file in `ls -c1 $DESTINAZIONE/$NOME_BACKUP*{_full,_inc,_list}*`
  do
    if [[ $file < $OLDEST ]]; then
	  _stampa cancello $file
	  rm $file
	fi
  done
  echo "-->"
fi
if [ $NUMERO_BACKUP_COMPLETI -eq 0 ]; then
  _stampa -n 'Non ci sono backup interi, procedo ad un backup intero ... '
  _completo
elif [ $NUMERO_BACKUP_INC -ge $NUMERO_MAX_BACKUP_INCREMENTALI ]; then
  _stampa -n 'Troppi backup incrementali, procedo ad un backup intero ... '
  _completo
else
  _stampa -n 'Inizio backup incrementale ... '
  _incrementale
fi
_stampa ok
_esci 0

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
NOME_BACKUP=prove
ORIGINE=/home/sandro/prove
DESTINAZIONE=/home/sandro/backup
NUMERO_MAX_BACKUP_COMPLETI=3
NUMERO_MAX_BACKUP_INCREMENTALI=5

DATA=`date +%y%m%d_%H%M%S`
NOME_FILE_INC=$DESTINAZIONE"/"$NOME_BACKUP"_"$DATA"_inc.tar.gz"
NOME_FILE_COMPL=$DESTINAZIONE"/"$NOME_BACKUP"_"$DATA"_full.tar.gz"
NOME_FILE_LISTA=$DESTINAZIONE"/"$NOME_BACKUP"_list"

#Funzione uscita
function _esci
{
  T_FINE=`date +%s%N`
  T_DIFF=$((T_FINE - T_INIZIO))
  echo "Tempo impiegato: $((T_DIFF/1000000000))sec$((T_DIFF/1000000%1000))msec"
  exit $1
}

#Controlla l'esistenza delle cartelle di origine e destinazione
function _check_exist
{
  echo -n "controllo esistenza cartelle  ... "
  if [ ! -d $ORIGINE ]; then
    echo 'origine non esiste'
    _esci 1
  elif [ ! -d $DESTINAZIONE ]; then
    echo 'destinazione non esiste'
    _esci 1
  fi
  echo 'ok'
}

#Funzione backup, lancia il comando tar e fa una copia del file lista
function _backup
{
  /bin/tar -C $ORIGINE/.. --listed-incremental=$NOME_FILE_LISTA\
           -czf $1 prove
  cp $NOME_FILE_LISTA $NOME_FILE_LISTA"-"$DATA.idx
}

function _incrementale
{
  _backup $NOME_FILE_INC
}

function _intero
{
  rm -f $NOME_FILE_LISTA
  _backup $NOME_FILE_COMPL
}

_check_exist
NUMERO_BACKUP_COMPLETI=`ls -l $DESTINAZIONE|grep "_full." 2> /dev/null |wc -l`
#str=`ls -rl $DESTINAZIONE/$NOME_BACKUP*{full,inc}* 2> /dev/null | grep -m 1 -n "_full."`
#idx=`expr index "$str" ":"`
NUMERO_BACKUP_INC=`ls -rl $DESTINAZIONE/$NOME_BACKUP*{full,inc}* 2> /dev/null | grep -m 1 -n "_full."|cut -d':' -f1`
if [ -z $NUMERO_BACKUP_INC ]; then
  echo imposto idx a 0
   NUMERO_BACKUP_INC=0
else
  ((NUMERO_BACKUP_INC -= 1))
fi
echo Numero backup completi=$NUMERO_BACKUP_COMPLETI
echo Numero backup incrementali=$NUMERO_BACKUP_INC
if [ $NUMERO_BACKUP_COMPLETI -eq 0 ]; then
  echo -n 'Non ci sono backup interi, procedo ad un backup intero ... '
  _intero
elif [ $NUMERO_BACKUP_INC -ge $NUMERO_MAX_BACKUP_INCREMENTALI ]; then
  echo -n 'Troppi backup incrementali, procedo ad un backup intero ... '
  _intero
else
  echo -n 'Inizio backup incrementale ... '
  _incrementale
fi
echo ok
_esci

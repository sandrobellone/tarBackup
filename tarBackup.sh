#!/bin/bash
#tarBackup.sh
#versione 0.10 del 02 Ottobre 2017
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
NOME_BACK=prove2
ORIG=/home/sandro
DEST=/home/sandro/backup
NMAX_BACK_COMPL=3
NMAX_BACK_INCR=5
HOME="${0%/*}" #parameter expansion
DEBUG=0
LOGGING=0

DATA=`date +%y%m%d_%H%M%S`
NOME_FILE_INC=$DEST"/"$NOME_BACK"_"$DATA"_inc.tar.gz"
NOME_FILE_COMPL=$DEST"/"$NOME_BACK"_"$DATA"_full.tar.gz"
NOME_FILE_LISTA=$DEST"/"$NOME_BACK"_"$DATA"_list".idx
NOME_ULTIMO_FILE_LISTA=$DEST"/"$NOME_BACK"_list".idx


#Funzione stampa
function _stampa
{
  if [ $LOGGING -eq 1 ]; then
    echo $@ | tee -a $HOME/tarBackup_log.txt
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

#Controlla l'esistenza delle cartelle di origine e destinazione
function _check_exist
{
  _stampa -n "controllo esistenza cartelle  ... "
  if [ ! -d $ORIG ]; then
    _stampa 'origine non esiste'
    _esci 1
  elif [ ! -d $DEST ]; then
    _stampa 'destinazione non esiste'
    _esci 1
  fi
  _stampa 'ok'
}

#Funzione backup, lancia il comando tar e fa una copia del file lista
function _backup
{
  NOME_CARTELLA_ORIG=`echo $ORIG| tr '/' '\n'|tail -n1`
  if [ $DEBUG -eq 1 ]; then
    _stampa -e '\n-->'/bin/tar -C $ORIG/..\
           --listed-incremental=$NOME_FILE_LISTA\
           -czf $1 $NOME_CARTELLA_ORIG\
		   --exclude=$NOME_BACK*{_full,_inc,_list}*
  fi
  /bin/tar -C $ORIG/..\
           --listed-incremental=$NOME_FILE_LISTA\
           -czf $1 $NOME_CARTELLA_ORIG\
		   --exclude=$NOME_BACK*{_full,_inc,_list}*
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
	  cat $HOME/tarBackup_Readme.txt
      _esci 0
      ;;
	d)
	  _stampa "-->Debug attivato"
	  DEBUG=1
	  ;;
	l)
	  echo "-->Logging attivato"
	  LOGGING=1
	  echo "---------------------------" >> $HOME/tarBackup_log.txt
	  echo "-->" inizio Logging - `date` >> $HOME/tarBackup_log.txt
	  ;;
    \?)
      _stampa "Opzione non valida: -$OPTARG" >&2
      _esci 1
      ;;
  esac
done
_check_exist
if [ $DEBUG -eq 1 ]; then
  _stampa "-->HOME="$HOME
  _stampa "-->NOME_BACK="$NOME_BACK
  _stampa "-->NOME_FILE_COMPL"=$NOME_FILE_COMPL
  _stampa "-->NOME_FILE_INC"=$NOME_FILE_INC
fi
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

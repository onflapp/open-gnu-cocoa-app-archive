/*
 * stringInterpreter.c
 * Copyright 1992-2003 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  1992-12-05
 * modified: 25.03.96
 *
 * functions for accessing device configuration files
 * basically all these functions search for an identifier (id) within a string (data).
 * The information behind the identifier (id) will be returned in a specified manner.
 */

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "types.h"
#include "stringInterpreter.h"
#include "vhfCommonFunctions.h"

static char *getString(char* cp, char** string);
static char *getStringS(char* cp, char** string);
static char *getInt(char *cp, int *value);
static char *getChar(char *cp, char *value);
static char *getBYTE(char *cp, BYTE *value);
static char *getWORD(char *cp, WORD *value);
static char *getLONG(char *cp, LONG *value);
static char *getCoord(char *cp, float *value);

#define STRING_LEN	100

/* created:			02.03.95
 * modified:		02.03.95
 * purpose:			get length of a string entry up to an " but skip \"
 * parameter:		string	pointer to the beginning of the string (String\"Bla\\ Bla")
 * return value:	length of string entry
 */
LONG vhfGetLengthOfStringEntry(const char *string)
{	LONG	len;

	/* get the length up to a '"' without a preceeding '\' */
	for (len=0; string[len] != 0; len++)
	{
		len += strcspn(string+len, "\"");
		if(string[len-1] != '\\')
			break;
	}

	return len;
}

/* created:			02.03.95
 * modified:		02.03.95
 * purpose:			encrypt string entry "c:\Pfad" -> \"c:\\Pfad\"
 * parameter:		string	pointer to the source string
 *					target	pointer to the destination string (have to be allocated with strlen*2)
 * return value:	TRUE
 */
char vhfEncryptStringEntry(const char *from, char *target)
{	LONG		len, i;
	char		*to, str[2];

	to = target;
	*to = 0;
	len = strlen(from);
	for(i=0; i < len; )
	{
		switch( from[i] )
		{
			case 0x1b:		/* escape */
				strcat(to, "\\e");
				break;
			case '\"':
				strcat(to, "\\\"");
				break;
			case '\\':
				strcat(to, "\\\\");
				break;
			case '\n':
				strcat(to, "\\\n");
				break;
			case '\r':
				strcat(to, "\\\r");
				break;
			default:
				str[0] = from[i];
				str[1] = 0;
				strcat(to, str);
				break;
		}
	}

	return 1;
}

/* created:			02.03.95
 * modified:		02.03.95
 * purpose:			decrypt string entry \"c:\\Pfad\" -> "c:\Pfad"
 * parameter:		string	pointer to the source string
 *					target	pointer to the destination string (have to be allocated with len+1)
 * return value:	TRUE
 */
char vhfDecryptStringEntry(const char *string, char *target)
{	LONG	len, i;
	char	*from, *to;

	from = (char*)string;
	to = target;
	len = vhfGetLengthOfStringEntry(from);

	for(i=0; i <= len; )
	{
		/* copy the string up to '\' (or the end " ) */
		i = strcspn(from, "\\\"");
		strncpy(to, from, i);
		to += i;
		from += i;			/* from = \ or " */
		if(*from == '\"' || *from == 0)	/* ready */
			break;
		switch( from[1] )
		{
			case 'e':		/* escape */
				*to = 0x1b;
				to++;
				break;
			case '\"':
				*to = '\"';
				to++;
				break;
			case 'n':
				*to = '\n';
				to++;
				break;
			case 'r':
				*to = '\r';
				to++;
				break;
			default:		/* '\' */
				*to = *from;
				to++;
				break;
		}
		from += 2;
	}
	*to = 0;

	return 1;
}

/* created:			21.07.93
 * modified:		21.07.93
 * purpose:			get number of entries 'id' in 'data'
 * parameter:		data
 *					id
 * return value:	number of entries
 */
LONG vhfGetNumberOfEntries(char *data, char *id)
{	LONG	cnt = 0;

	while(1)
	{	if((data = strchr(data, '#')) && (!strncmp(data, id, strlen(id))))
		{	data += strlen(id);
			cnt++;
		}
		else if(!data)
			break;
		else
			data++;
	}
	return cnt;
}

/* created:			22.07.93
 * modified:		22.07.93
 * purpose:			get number of entries 'id' in 'data' before 'limit'
 * parameter:		data
 *					id
 * return value:	number of entries
 */
LONG vhfGetNumberOfEntriesBefore(char *data, char *id, char *limit)
{	LONG	cnt = 0;

	while(1)
	{	if((data = strchr(data, '#')) && (!strncmp(data, id, strlen(id))))
		{	data += strlen(id);
			cnt++;
		}
		else if(!data)
			break;
		else if((data = strchr(data, '#')) && (!strncmp(data, limit, strlen(limit))))
			break;
		else
			data++;
	}
	return cnt;
}

/*
 * modified:		15.12.92 01.11.93 13.03.94 22.07.94
 * purpose:			returns a string enclosed by '"' at 'id' in 'data'
 *					data will be modified!
 * parameter:		data	(string of the kind like the files '*.dev')
 *					id		(identifier e.g. '#MOV')
 *					string (a pointer to a string, memory will be allocated)
 * return value:	TRUE on success
 */
char vhfGetStringFromData(char *data, const char *id, char **string)
{	char	*cp;
	int		i;
	long	length;

	if(*string)
		free(*string);
	*string = 0l;

	if(!data || !id)
		return 0;

	if(cp = strstr(data, id))
	{
		/* to allow multiple equal ids, we simply disable the id */
		*cp = 0x01;

		/* get distance to first '"' */
		i = strcspn(cp, "\n\r\"");				/* cp = #MOV "PU\n\""... */
		if(cp[i] == '\"')
		{
			cp += i+1;							/* cp = PU\n\""... */
			/* get the length up to a '"' without a preceeding '\' */
			for (length=0; cp[length] != 0; )
			{
				length += strcspn(cp, "\"");
				if(cp[length-1] != '\\')
					break;
			}
			if(!length)
				return 1;
			/* allocate memory for the string */
			if(*string = malloc(length+1))
			{	char	*target;

				target = *string;
				for(i=0; i <= length; )
				{
					/* copy the string up to '\' */
					i = strcspn(cp, "\\\"");
					strncpy(target, cp, i);
					target += i;
					cp += i;			/* cp = \ or " */
					if(*cp == '\"')	/* ready */
						break;
					switch( cp[1] )
					{
						case 'e':		/* escape */
							*target = 0x1b;
							target++;
							break;
						case '\"':
							*target = '\"';
							target++;
							break;
						case 'n':
							*target = '\n';
							target++;
							break;
						case 'r':
							*target = '\r';
							target++;
							break;
						default:		/* '\' */
							*target = *cp;
							target++;
							break;
					}
					cp += 2;
				}
				*target = 0;

				return 1;
			}
		}
	}

	return 0;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
last modified:	05.01.93
purpose:		returns an int behind the position of id in data
				the single string must not be longer than 100
parameter:		data	(string of the kind like the files '*.dev')
				id		(identifier e.g. '#XMX')
				value
return value:	TRUE on success
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
char vhfGetIntFromData(char *data, const char *id, ...)
{	va_list		flag_p;
	int			*flag;
	char		*cp, str[STRING_LEN], *err_p;

	cp=strstr(data, id);															/* id in cfg suchen						*/
	if(cp)
	{
		*cp = 0x01;																	/* einmal einlesen genuegt, also #->1	*/
		cp+=strlen(id);
		cp+=strcspn(cp,".+-0123456789");											/* pointer auf ersten flag setzen		*/
		va_start(flag_p,radix);
		while(flag=va_arg(flag_p, int*))
		{
			memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
			strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
			if(!str[0])																/* zu wenig eintraege					*/
			{	va_end(flag_p);
				return(0);
			}
			cp+=strlen(str)+1;														/* set pointer behind digits	*/
			cp+=strcspn(cp,".+-0123456789");										/* set pointer to next flag		*/
			*flag=(int)strtol(str, &err_p, 10);
			if(err_p && *err_p)														/* nicht als hex auswertbare ziffer ...	*/
			{	va_end(flag_p);
				return(0);														/* ... in str							*/
			}
		}
		va_end(flag_p);

		return(1);
	}

	return(0);
}

/*
 * modified:		02.05.93 17.08.94
 * purpose:			return some types beginning at the position of 'id' inside 'data'
 *					the single string must not be longer than 100 characters
 * parameter:		data	(string of the kind like the files '*.dev')
 *					types	("sciisWBL")
 *							s	string
 *							S	String between ' ' instead of '"'
 *							c	character
 *							i	integer
 *							B	BYTE
 *							W	WORD
 *							L	LONG
 *					id		(identifier e.g. "#XMX")
 *					value
 * return value:	TRUE on success
 */
char vhfGetTypesFromData(char *data, const char *types, const char *id, ...)
{	va_list		flag_p;
	void		*flag;
	char		*cp;
	int			i;

	cp=strstr(data, id);															/* id in cfg suchen						*/
	if(cp)
	{
		*cp = 0x01;																	/* einmal einlesen genuegt, also #->1	*/
		cp+=strlen(id);
		va_start(flag_p,radix);
		for(i=0; i<strlen(types) && (flag=va_arg(flag_p, void*)); i++)
		{
			switch(types[i])
			{
				case 's':
					if(!(cp = getString(cp, (char**)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'S':
					if(!(cp = getStringS(cp, (char**)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'c':
					if(!(cp=getChar(cp, (char*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'i':
					if(!(cp=getInt(cp, (int*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'B':
					if(!(cp=getBYTE(cp, (BYTE*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'W':
					if(!(cp=getWORD(cp, (WORD*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'L':
					if(!(cp=getLONG(cp, (LONG*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
				case 'C':
					if(!(cp=getCoord(cp, (float*)flag)))
					{	va_end(flag_p);
						return 0;
					}
					break;
			}
		}
		va_end(flag_p);

		return(1);
	}

	return(0);
}

/*
 * modified:		28.06.93 16.09.93 13.03.94 24.05.94 24.04.95
 * purpose:			returns a string enclosed by '"' in 'cp'
 *					cp will be modified!
 * parameter:		cp		(string of the kind like the files '*.dev')
 *					string (a pointer to a string, memory will be allocated)
 * return value:	new position of cp or FALSE
 */
static char *getString(char* cp, char** string)
{	int		i;
	long	length;

	if(*string)
		free(*string);
	*string = 0;

	/* get distance to first '"' */
	i = strcspn(cp, "\n\r\"");				/* cp = #MOV "PU\n\""... */
	if(cp[i] == '\"')
	{
		cp += i+1;							/* cp = PU\n\""... */
		/* get the length up to a '"' without a preceeding '\' */
		for (length=0; cp[length] != 0; )
		{
			length += strcspn(cp, "\"");
			if(cp[length-1] != '\\')
				break;
		}
		if(!length)
			return cp;
		/* allocate memory for the string */
		if(*string = malloc(length+1))
		{	char	*target;

			target = *string;
			for(i=0; i <= length; )
			{
				/* copy the string up to '\'or '"' */
				i = strcspn(cp, "\\\"");
				strncpy(target, cp, i);
				target += i;
				cp += i;			/* cp = \ or " */
				if(*cp == '\"')	/* '"' -> ready */
				{	cp++;
					break;
				}
				else switch( cp[1] )	/* \x */
				{
					case 'e':		/* escape */
						*target = 0x1b;
						target++;
						break;
					case '0':
						if(cp[2] == 'x')
						{	unsigned	hex;
							char		endp[10];

							hex = strtol(cp+1, (char**)&endp, 0);
							*target = hex;
						}
					case '\"':		/* '"' */
						*target = '\"';
						target++;
						break;
					case 'n':		/* new line */
						*target = '\n';
						target++;
						break;
					case 'r':		/* carriage return */
						*target = '\r';
						target++;
						break;
					case '\n':
					case '\r':
					case '\t':
					case ' ':
						cp += strspn(cp, "\\\n\r\t ");	/* goto new line */
						continue;
					default:		/* '\' */
						*target = cp[1];
						target++;
						break;
				}
				cp += 2;
			}
			*target = 0;

			return cp;
		}
	}

	return 0;
}

/* created:			17.08.94
 * modified:		17.08.94 01.09.94
 * purpose:			returns a string enclosed by ' ' in 'cp'
 *					cp will be modified!
 * parameter:		cp		(string of the kind like the files '*.dev')
 *					string (a pointer to a string, memory will be allocated)
 * return value:	new position of cp or FALSE
 */
static char *getStringS(char* cp, char** string)
{	int		i;
	long	length;

	*string = 0;

	/* get distance to first char not equal to ' ' */
	i = strspn(cp, " \t");				/* cp = " line circle ..." */
	if( i > strcspn(cp, "\n\r") )		/* the string must be in this line */
		return 0;
	{
		cp += i;							/* cp = "line circle ..." */
		/* get the length up to a ' ' */
		length = strcspn(cp, " \t\r\n");

		if(!length)
			return cp;
		/* allocate memory for the string */
		if(*string = malloc(length+1))
		{	char	*target;

			target = *string;
			strncpy(target, cp, length);
			target[length] = 0;

			cp += strcspn(cp, " \t");	/* cp = " circle ..." */

			return cp;
		}
	}

	return 0;
}

static char *getInt(char *cp, int *value)
{	char		str[STRING_LEN], *err_p;

	if(cp)
	{
		cp+=strcspn(cp,".+-0123456789");										/* pointer auf ersten flag setzen		*/
		memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
		strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
		if(!str[0])																/* zu wenig eintraege					*/
			return(0);
		cp+=strlen(str)+1;														/* cp auf naechsten eintrag setzen	*/
		*value=(int)strtol(str, &err_p, 10);
		if(err_p && *err_p)														/* nicht als hex auswertbare ziffer ...	*/
			return(0);															/* ... in str							*/

		return(cp);
	}

	return(0);
}

/*
 * modified:	07.03.94 15.08.94
 */
static char *getBYTE(char *cp, BYTE *value)
{	char	str[STRING_LEN], *err_p;

	if(cp)
	{
		cp+=strcspn(cp,".+-0123456789\r\n");									/* pointer auf ersten flag setzen		*/
		if(*cp == '\r' || *cp == '\n')
		{	value = 0;
			return(0);
		}
		memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
		strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
		if(!str[0])																/* zu wenig eintraege					*/
		{	value = 0;
			return(0);
		}
		cp+=strlen(str)+1;														/* cp auf naechsten eintrag setzen	*/
		*value=(BYTE)strtol(str, &err_p, 10);
		if(err_p && *err_p)														/* nicht als hex auswertbare ziffer ...	*/
			return(0);															/* ... in str							*/

		return(cp);
	}

	value = 0;

	return(0);
}

static char *getWORD(char *cp, WORD *value)
{	char		str[STRING_LEN], *err_p;

	if(cp)
	{
		cp+=strcspn(cp,".+-0123456789");										/* pointer auf ersten flag setzen		*/
		memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
		strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
		if(!str[0])																/* zu wenig eintraege					*/
			return(0);
		cp+=strlen(str)+1;														/* cp auf naechsten eintrag setzen	*/
		*value=(WORD)strtol(str, &err_p, 10);
		if(err_p && *err_p)														/* nicht als hex auswertbare ziffer ...	*/
			return(0);															/* ... in str							*/

		return(cp);
	}

	return(0);
}

static char *getLONG(char *cp, LONG *value)
{	char		str[STRING_LEN], *err_p;

	if(cp)
	{
		cp+=strcspn(cp,".+-0123456789");										/* pointer auf ersten flag setzen		*/
		memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
		strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
		if(!str[0])																/* zu wenig eintraege					*/
			return(0);
		cp+=strlen(str)+1;														/* cp auf naechsten eintrag setzen	*/
		*value=(LONG)strtol(str, &err_p, 10);
		if(err_p && *err_p)														/* nicht als hex auswertbare ziffer ...	*/
			return(0);															/* ... in str							*/

		return(cp);
	}

	return(0);
}

static char *getCoord(char *cp, float *value)
{	char		str[STRING_LEN];

	if(cp)
	{
		cp+=strcspn(cp,".+-0123456789");										/* pointer auf ersten flag setzen		*/
		memset(str, 0, STRING_LEN);												/* str loeschen es folgt nur strncpy	*/
		strncpy(str, cp, Min(strcspn(cp," \r\n#"), STRING_LEN));				/* eintrag in hilfsstring kopieren		*/
		if(!str[0])																/* zu wenig eintraege					*/
			return(0);
		cp+=strlen(str)+1;														/* cp auf naechsten eintrag setzen	*/

		*value=(float)atof(str);

		return(cp);
	}

	return(0);
}

static char *getChar(char *cp, char *value)
{
	if(cp)
	{
		cp+=strspn(cp," \t");	/* set pointer to begin of character */
		*value=*cp;
		cp++;

		return(cp);
	}

	return(0);
}

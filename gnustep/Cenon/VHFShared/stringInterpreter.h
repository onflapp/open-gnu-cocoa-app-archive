/*
 * stringInterpreter.h
 * Copyright 1992-1996 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  05.12.92
 * modified: 25.03.96
 */

LONG	vhfGetLengthOfStringEntry(const char *string);
char	vhfEncryptStringEntry(const char *string, char *target);
char	vhfDecryptStringEntry(const char *string, char *target);
LONG	vhfGetNumberOfEntries(char *data, char *id);
LONG	vhfGetNumberOfEntriesBefore(char *data, char *id, char *limit);
char	vhfGetStringFromData(char *data, const char *id, char **string);
char	vhfGetIntFromData(char *data, const char *id, ...);
char	vhfGetTypesFromData(char *data, const char *types, const char *id, ...);

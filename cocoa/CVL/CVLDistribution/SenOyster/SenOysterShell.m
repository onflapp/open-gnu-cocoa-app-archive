/*$Id: SenOysterShell.m,v 1.10 2003/07/25 10:22:28 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenOysterShell.h"
#import "NSString.SenOysterRegex.h"
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSException.h>
#import <SenFoundation/SenUtilities.h>

#ifdef RHAPSODY
#import <Perl/EXTERN.h>
#import <Perl/perl.h>
#else
#import <EXTERN.h>
#import <perl.h>
static PerlInterpreter *my_perl;
#endif

#import <math.h>

@interface SenOysterShell (_Private)
- (void) makePerl;
- (void) removePerl;
- (SV *) svWithName:(NSString *) name;
- (AV *) avWithName:(NSString *) name;
- (HV *) hvWithName:(NSString *) name;
@end


@implementation SenOysterShell

#define CSTRING(s)	(char *)[(s) cString]

NSString *SenOysterEvaluationFailedException = @"SenOysterEvaluationFailedException";
NSString *SenOysterVariableNotFoundException = @"SenOysterVariableNotFoundException";

+ (SenOysterShell *) sharedOyster
{
    static SenOysterShell *sharedOyster = nil;
    if (!sharedOyster) {
        ASSIGN(sharedOyster, [self oyster]);
    }
    return sharedOyster;
}


+ (SenOysterShell *) oyster
{
    return [[[self alloc] init] autorelease];
}


- init
{
    [super init];
    [self makePerl];
    if (!_perl) {
        [self dealloc];
        self = nil;
    }
    return self;
}


- (void) dealloc
{
    [self removePerl];
    [super dealloc];
}


- (void) makePerl
{
    if (!_perl) {
        char *startCommand[] = {"", "-e", "sub oyster_eval {eval $_[0]; die $@ if $@;}"};
        (PerlInterpreter *) _perl = perl_alloc();
#ifndef RHAPSODY
        /*  On Tuesday, July 8, 2003, at 7:37AM, Jason Toffaletti wrote:
            After a little searching, I found out that you must initialize my_perl with 
            perl_alloc(). I looked at the code and discovered that there is already 
            a _perl variable which is the interpreter and I simply tried doing 
            my_perl = _perl; after _perl was initialized. This worked like a charm, 
            so I guess the best thing to do would be to remove the _perl variable from 
            the class interface and just use the static my_perl variable. I can submit 
            a patch to you if this sounds like the right thing to do.
        */
        my_perl = _perl;
#endif
        perl_construct ((PerlInterpreter *) _perl);
        perl_parse ((PerlInterpreter *)_perl, NULL, 3, startCommand, (char **) NULL);
        perl_run ((PerlInterpreter *) _perl);
    }
}


- (void) removePerl
{
    if (_perl) {
        perl_destruct ((PerlInterpreter *)_perl);
        perl_free ((PerlInterpreter *)_perl);
        _perl = NULL;
    }
}
@end

@implementation SenOysterShell (Evaluation)
- (void) eval:(NSString *) command
{
    dSP;
    SV *sv;
    NSString *error = nil;

    ENTER;
    SAVETMPS;

    PUSHMARK (sp);
    XPUSHs (sv_2mortal (newSVpv (CSTRING (command), 0)));
    PUTBACK;

    (void) perl_call_pv ("oyster_eval", G_EVAL | G_SCALAR);
    
    SPAGAIN;

#ifdef RHAPSODY
    sv = GvSV(errgv);
#else
    sv = GvSV(PL_errgv);
#endif
    if ((sv != NULL) && SvTRUE(sv)) {
#ifdef RHAPSODY
        error = [NSString stringWithCString:SvPV (sv, na)];
#else
        error = [NSString stringWithCString:SvPV (sv, PL_na)];
#endif
        (void) POPs;
    }
    else {
        (void) POPi;
    }
	
    PUTBACK;
    FREETMPS;
    LEAVE;

    if (error) {
        NSString *reason = [error stringByApplyingReplacementOperator:@"s/ at \\(eval.*//"];
        [[NSException exceptionWithName:SenOysterEvaluationFailedException reason:reason userInfo:nil] raise];
    }
}
@end


@implementation SenOysterShell (ScalarVariables)
- (SV *) svWithName:(NSString *) name
{
    SV *sv = perl_get_sv (CSTRING (name), FALSE);
    if (!sv) {
        [NSException raise:SenOysterVariableNotFoundException format:@"Scalar not found: %@", name];
    }
    return sv;
}


- (NSString *) stringWithName:(NSString *) name
{
    volatile NSString *result = nil;
    NS_DURING
        STRLEN length;
        SV *sv = [self svWithName:name];
        char *str = (sv != NULL) ? SvPV (sv, length) : NULL;
        result = (str != NULL) ? [NSString stringWithCString:str length:length] : nil;
    NS_HANDLER
        result = nil;
        /* ignore exception, will return nil */ ;
    NS_ENDHANDLER
    return (NSString *)result;
}


- (void) setString:(NSString *) value forName:(NSString *) name
{
    SV *sv = perl_get_sv(CSTRING(name), TRUE);
    sv_setpv (sv, CSTRING(value));
}


- (int) intWithName:(NSString *) name
{
    SV *sv = perl_get_sv (CSTRING (name), FALSE);
    return sv ? SvIV([self svWithName:name]) : NSNotFound;
}


- (void) setIntValue:(int) value forName:(NSString *) name
{
    SV *sv = perl_get_sv(CSTRING(name), TRUE);
    sv_setiv (sv, value);
}


- (double) doubleWithName:(NSString *) name
{
    SV *sv = perl_get_sv (CSTRING (name), FALSE);
    if(sv)
        return SvNV ([self svWithName:name]);
    else{
        [NSException raise:SenOysterVariableNotFoundException format:@"Double not found: %@", name];
        return 0.0; // Never reached
    }
}


- (void) setDoubleValue:(double) value forName:(NSString *) name
{
    SV *sv = perl_get_sv(CSTRING(name), TRUE);
    sv_setnv (sv, value);
}


- (NSNumber *) numberWithName:(NSString *) name
{
    SV *sv = [self svWithName:name];
    if (SvIOKp (sv)) {
        return [NSNumber numberWithInt:SvIV(sv)];
    }
    if (SvNOKp (sv)) {
        return [NSNumber numberWithDouble:SvNV(sv)];
    }
    return nil;
}
@end


@implementation SenOysterShell (ArrayVariables)
- (NSArray *) arrayWithName:(NSString *) name
{
    NSMutableArray *array = nil;
    AV *pArray = perl_get_av (CSTRING (name), FALSE);
    I32	pArrayCount = av_len (pArray) + 1;
    
    if (pArrayCount > 0) {
        int	i;
        array = [NSMutableArray array];
        for (i = 0; i < pArrayCount; i++) {
            STRLEN	length;
            SV *current = av_shift(pArray);
            char *s = SvPV(current, length);
            if (s) {
                [array addObject:[NSString stringWithCString:s length:length]];
            }
        }
    }
    return array;
}
@end


@implementation SenOysterShell (DictionaryVariables)
//- (NSDictionary *) dictionaryWithName:(NSString *) name;
//- (void) setDictionary:(NSDictionary *) value forName:(NSString *) name;
@end


@implementation SenOysterShell (ObjectVariables)
//- (id) objectWithName:(NSString *) name;
// Returns NSNumber, NSArray,  NSDictionary, NSString
@end

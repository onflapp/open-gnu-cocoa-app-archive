/* CVLUnwrapRequest.h created by stephane on Fri 25-Feb-2000 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import <TaskRequest.h>


// CVLUnwrapRequest calls script unwrap.sh (performs a gunzip | gnutar xf)
// It is useful to correct a bug with cvs: when a wrapper is retrieved by cvs update -R | -D, cvs forgets to unwrap it...
// Using this request, explicitly (is must follow a CvsUpdateRequest), will correct this problem
// unwrap.sh path is stored in UserDefaults <unwrap>
// This request is called by -[CvsUpdateRequest end], if needed

@interface CVLUnwrapRequest : TaskRequest
{
}

+ (id) unwrapRequestForWrapper:(NSString *)aPath;

@end

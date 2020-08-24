//
//  SenCheckpoint.m
//  SenFoundation
//
//  Created by William Swats on Tue Jan 27 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import "SenCheckpoint.h"
#import <sys/time.h>


void SenLogCheckpoint(NSString *aMsg)
    /*" This function prints out the present time in seconds and microseconds
        to standard output. This is used to test elasped time in application
        development.
    "*/
{
        struct timeval tp;
        struct timezone tzp;
        
        gettimeofday(&tp, &tzp);
        NSLog(@"Time in seconds is %d and microseconds is %d\n%@",
              tp.tv_sec, tp.tv_usec, aMsg);    
}

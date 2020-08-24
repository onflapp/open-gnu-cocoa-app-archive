//
//  KTMatrixDenseEnumerator
//  KTMatrix collection class cluster
//
//  Enumerator classes for the dense implementations of KTMatrix
//
//  Copyright (c) 2002 Chris Purcell. All rights reserved.
//
//  You may use this code for whatever purposes you wish.
//  This code comes with no warranties, implied or otherwise.
//  Using it may damage your data. It shouldn't, but save a copy first.
//  That's a good idea anyway, actually.
//

#import <Foundation/Foundation.h>
#import "KTMatrix.h"

@interface KTMatrixDenseEnumerator : NSEnumerator<KTMatrixEnumerator>
{
    const id *array;
    BOOL broken;
    unsigned capacity;
    unsigned offset;
    id source;
}

- (id)initWithArray:(const id *)array
              ofCapacity:(unsigned)capacity
         collection:(id)collection;

@end

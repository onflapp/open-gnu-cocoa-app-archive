#include <Foundation/Foundation.h>

NSString *_NSNewStringFromCString( char * s )
{
    return [ NSString stringWithCString: s ];
}

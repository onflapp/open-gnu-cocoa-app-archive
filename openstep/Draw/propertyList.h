/* Convenience methods for Property List-izing */

typedef enum { FromPropertyList = 0, ToPropertyList = 1 } ConversionDirection;

/* The following functions return autoreleased objects. */

extern id propertyListFromArray(NSArray *array);
extern id propertyListFromFloat(float f);
extern id propertyListFromInt(int i);
extern id propertyListFromNSColor(NSColor *color);
extern id propertyListFromNSRect(NSRect rect);
extern id propertyListFromNSSize(NSSize size);
extern id propertyListFromNSPoint(NSPoint point);

/* The following functions return retained objects. */

extern NSMutableArray *arrayFromPropertyList(id plist, NSString *directory, NSZone *zone);
extern NSColor *colorFromPropertyList(id plist, NSZone *zone);
extern NSRect rectFromPropertyList(id plist);
extern NSSize sizeFromPropertyList(id plist);
extern NSPoint pointFromPropertyList(id plist);

#define PL_FLAG(plist, flag, key, direction) \
    if (direction == ToPropertyList) { \
        if (flag) [plist setObject:@"YES" forKey:key]; \
    } else { \
        flag = ([plist objectForKey:key] ? YES : NO); \
    }

#define PL_INT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromInt(value) forKey:key]; \
   } else { \
       value = [[plist objectForKey:key] intValue]; \
       if (![plist objectForKey:key]) value = 0; \
   }

#define PL_FLOAT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromFloat(value) forKey:key]; \
   } else { \
       value = [[plist objectForKey:key] floatValue]; \
       if (![plist objectForKey:key]) value = 0.0; \
   }

#define PL_COLOR(plist, value, key, direction, zone) \
   if (direction == ToPropertyList) { \
       if (value) [plist setObject:propertyListFromNSColor(value) forKey:key]; \
   } else { \
       value = colorFromPropertyList([plist objectForKey:key], zone); \
   }

#define PL_RECT(plist, value, key, direction) \
   if (direction == ToPropertyList) { \
       [plist setObject:propertyListFromNSRect(value) forKey:key]; \
   } else { \
       value = rectFromPropertyList([plist objectForKey:key]); \
   }

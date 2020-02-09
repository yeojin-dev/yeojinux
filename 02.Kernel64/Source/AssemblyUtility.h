#ifndef __ASSEMBLYUTILITY_H__
#define __ASSEMBLYUTILITY_H__

#include "Types.h"

// 어셈블리 유틸리티 함수 정의
BYTE kInPortByte( WORD wPort );
void kOutPortByte( WORD wPort, BYTE bData );

#endif /*__ASSEMBLYUTILITY_H__*/

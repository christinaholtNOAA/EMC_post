 SUBROUTINE POLATES4(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI, &
                     NO,RLAT,RLON,IBO,LO,GO,IRET)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! $Revision: 71314 $
!
! SUBPROGRAM:  POLATES4   INTERPOLATE SCALAR FIELDS (SPECTRAL)
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM PERFORMS SPECTRAL INTERPOLATION
!           FROM ANY GRID TO ANY GRID FOR SCALAR FIELDS.
!           IT REQUIRES THAT THE INPUT FIELDS BE UNIFORMLY GLOBAL.
!           OPTIONS ALLOW CHOICES BETWEEN TRIANGULAR SHAPE (IPOPT(1)=0)
!           AND RHOMBOIDAL SHAPE (IPOPT(1)=1) WHICH HAS NO DEFAULT;
!           A SECOND OPTION IS THE TRUNCATION (IPOPT(2)) WHICH DEFAULTS 
!           TO A SENSIBLE TRUNCATION FOR THE INPUT GRID (IF OPT(2)=-1).
!           NOTE THAT IF THE OUTPUT GRID IS NOT FOUND IN A SPECIAL LIST,
!           THEN THE TRANSFORM BACK TO GRID IS NOT VERY FAST.
!           THIS SPECIAL LIST CONTAINS GLOBAL CYLINDRICAL GRIDS,
!           POLAR STEREOGRAPHIC GRIDS CENTERED AT THE POLE
!           AND MERCATOR GRIDS.
!           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
!           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
!           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
!             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
!             (KGDS(1)=001) MERCATOR CYLINDRICAL
!             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
!             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
!             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
!             (KGDS(1)=203) ROTATED EQUIDISTANT CYLINDRICAL (E-STAGGER)
!             (KGDS(1)=205) ROTATED EQUIDISTANT CYLINDRICAL (B-STAGGER)
!           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
!           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
!           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED.
!           ON THE OTHER HAND, THE OUTPUT CAN BE A SET OF STATION POINTS
!           IF KGDSO(1)<0, IN WHICH CASE THE NUMBER OF POINTS
!           AND THEIR LATITUDES AND LONGITUDES MUST BE INPUT.
!           OUTPUT BITMAPS WILL NOT BE CREATED.
!        
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
! 2001-06-18  IREDELL  IMPROVE DETECTION OF SPECIAL FAST TRANSFORM
! 2015-01-27  GAYNO    REPLACE CALLS TO GDSWIZ WITH NEW MERGED
!                      VERSION OF GDSWZD.
!
! USAGE:    CALL POLATES4(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
!    &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
!
!   INPUT ARGUMENT LIST:
!     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
!                IPOPT(1)=0 FOR TRIANGULAR, IPOPT(1)=1 FOR RHOMBOIDAL;
!                IPOPT(2) IS TRUNCATION NUMBER
!                (DEFAULTS TO SENSIBLE IF IPOPT(2)=-1).
!     KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
!     KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
!                (KGDSO(1)<0 IMPLIES RANDOM STATION POINTS)
!     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
!     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
!     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
!     IBI      - INTEGER (KM) INPUT BITMAP FLAGS (MUST BE ALL 0)
!     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
!     GI       - REAL (MI,KM) INPUT FIELDS TO INTERPOLATE
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)<0)
!     RLAT     - REAL (NO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)<0)
!     RLON     - REAL (NO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)<0)
!
!   OUTPUT ARGUMENT LIST:
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)>=0)
!     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)>=0)
!     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)>=0)
!     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
!     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
!     GO       - REAL (MO,KM) OUTPUT FIELDS INTERPOLATED
!     IRET     - INTEGER RETURN CODE
!                0    SUCCESSFUL INTERPOLATION
!                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
!                3    UNRECOGNIZED OUTPUT GRID
!                41   INVALID NONGLOBAL INPUT GRID
!                42   INVALID SPECTRAL METHOD PARAMETERS
!
! SUBPROGRAMS CALLED:
!   GDSWZD       GRID DESCRIPTION SECTION WIZARD
!   SPTRUN       SPECTRALLY TRUNCATE GRIDDED SCALAR FIELDS
!   SPTRUNS      SPECTRALLY INTERPOLATE SCALARS TO POLAR STEREO.
!   SPTRUNM      SPECTRALLY INTERPOLATE SCALARS TO MERCATOR
!   SPTRUNG      SPECTRALLY INTERPOLATE SCALARS TO STATIONS
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 USE GDSWZD_MOD
!
 IMPLICIT NONE
!
 INTEGER,          INTENT(IN   ) :: IPOPT(20), KGDSI(200)
 INTEGER,          INTENT(IN   ) :: KGDSO(200), MI, MO
 INTEGER,          INTENT(IN   ) :: IBI(KM), KM
 INTEGER,          INTENT(  OUT) :: IBO(KM), IRET
!
 LOGICAL*1,        INTENT(IN   ) :: LI(MI,KM)
 LOGICAL*1,        INTENT(  OUT) :: LO(MO,KM)
!
 REAL,             INTENT(IN   ) :: GI(MI,KM)
 REAL,             INTENT(INOUT) :: RLAT(MO),RLON(MO)
 REAL,             INTENT(  OUT) :: GO(MO,KM)
!
 REAL,             PARAMETER     :: FILL=-9999.
 REAL,             PARAMETER     :: RERTH=6.3712E6
 REAL,             PARAMETER     :: PI=3.14159265358979
 REAL,             PARAMETER     :: DPR=180./PI
!
 INTEGER                         :: IDRTI, IDRTO, IG, JG, IM, JM
 INTEGER                         :: IGO, JGO, IMO, JMO
 INTEGER                         :: ISCAN, JSCAN, NSCAN
 INTEGER                         :: ISCANO, JSCANO, NSCANO
 INTEGER                         :: ISKIPI, JSKIPI
 INTEGER                         :: IMAXI, JMAXI, ISPEC
 INTEGER                         :: IP, IPRIME, IPROJ, IROMB, K
 INTEGER                         :: MAXWV, N, NI, NJ, NPS, NO
!
 REAL                            :: DE, DR, DY
 REAL                            :: DLAT, DLON, DLATO, DLONO
 REAL                            :: GO2(MO,KM), H, HI, HJ
 REAL                            :: ORIENT
 REAL                            :: RLAT1, RLON1, RLAT2, RLON2, RLATI
 REAL                            :: XMESH, XP, YP
 REAL                            :: XPTS(MO), YPTS(MO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
 IRET=0
 IF(KGDSO(1).GE.0) THEN
   CALL GDSWZD(KGDSO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT,NO)
   IF(NO.EQ.0) IRET=3
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  AFFIRM APPROPRIATE INPUT GRID
!    LAT/LON OR GAUSSIAN
!    NO BITMAPS
!    FULL ZONAL COVERAGE
!    FULL MERIDIONAL COVERAGE
 IDRTI=KGDSI(1)
 IM=KGDSI(2)
 JM=KGDSI(3)
 RLON1=KGDSI(5)*1.E-3
 RLON2=KGDSI(8)*1.E-3
 ISCAN=MOD(KGDSI(11)/128,2)
 JSCAN=MOD(KGDSI(11)/64,2)
 NSCAN=MOD(KGDSI(11)/32,2)
 IF(IDRTI.NE.0.AND.IDRTI.NE.4) IRET=41
 DO K=1,KM
   IF(IBI(K).NE.0) IRET=41
 ENDDO
 IF(IRET.EQ.0) THEN
   IF(ISCAN.EQ.0) THEN
     DLON=(MOD(RLON2-RLON1-1+3600,360.)+1)/(IM-1)
   ELSE
     DLON=-(MOD(RLON1-RLON2-1+3600,360.)+1)/(IM-1)
   ENDIF
   IG=NINT(360/ABS(DLON))
   IPRIME=1+MOD(-NINT(RLON1/DLON)+IG,IG)
   IMAXI=IG
   JMAXI=JM
   IF(MOD(IG,2).NE.0.OR.IM.LT.IG) IRET=41
 ENDIF
 IF(IRET.EQ.0.AND.IDRTI.EQ.0) THEN
   RLAT1=KGDSI(4)*1.E-3
   RLAT2=KGDSI(7)*1.E-3
   DLAT=(RLAT2-RLAT1)/(JM-1)
   JG=NINT(180/ABS(DLAT))
   IF(JM.EQ.JG) IDRTI=256
   IF(JM.NE.JG.AND.JM.NE.JG+1) IRET=41
 ELSEIF(IRET.EQ.0.AND.IDRTI.EQ.4) THEN
   JG=KGDSI(10)*2
   IF(JM.NE.JG) IRET=41
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SET PARAMETERS
 IF(IRET.EQ.0) THEN
   IROMB=IPOPT(1)
   MAXWV=IPOPT(2)
   IF(MAXWV.EQ.-1) THEN
     IF(IROMB.EQ.0.AND.IDRTI.EQ.4) MAXWV=(JMAXI-1)
     IF(IROMB.EQ.1.AND.IDRTI.EQ.4) MAXWV=(JMAXI-1)/2
     IF(IROMB.EQ.0.AND.IDRTI.EQ.0) MAXWV=(JMAXI-3)/2
     IF(IROMB.EQ.1.AND.IDRTI.EQ.0) MAXWV=(JMAXI-3)/4
     IF(IROMB.EQ.0.AND.IDRTI.EQ.256) MAXWV=(JMAXI-1)/2
     IF(IROMB.EQ.1.AND.IDRTI.EQ.256) MAXWV=(JMAXI-1)/4
   ENDIF
   IF((IROMB.NE.0.AND.IROMB.NE.1).OR.MAXWV.LT.0) IRET=42
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  INTERPOLATE
 IF(IRET.EQ.0) THEN
   IF(NSCAN.EQ.0) THEN
     ISKIPI=1
     JSKIPI=IM
   ELSE
     ISKIPI=JM
     JSKIPI=1
   ENDIF
   IF(ISCAN.EQ.1) ISKIPI=-ISKIPI
   IF(JSCAN.EQ.0) JSKIPI=-JSKIPI
   ISPEC=0
!  SPECIAL CASE OF GLOBAL CYLINDRICAL GRID
   IF((KGDSO(1).EQ.0.OR.KGDSO(1).EQ.4).AND. &
       MOD(KGDSO(2),2).EQ.0.AND.KGDSO(5).EQ.0.AND.KGDSO(11).EQ.0) THEN
     IDRTO=KGDSO(1)
     IMO=KGDSO(2)
     JMO=KGDSO(3)
     RLON2=KGDSO(8)*1.E-3
     DLONO=(MOD(RLON2-1+3600,360.)+1)/(IMO-1)
     IGO=NINT(360/ABS(DLONO))
     IF(IMO.EQ.IGO.AND.IDRTO.EQ.0) THEN
       RLAT1=KGDSO(4)*1.E-3
       RLAT2=KGDSO(7)*1.E-3
       DLAT=(RLAT2-RLAT1)/(JMO-1)
       JGO=NINT(180/ABS(DLAT))
       IF(JMO.EQ.JGO) IDRTO=256
       IF(JMO.EQ.JGO.OR.JMO.EQ.JGO+1) ISPEC=1
     ELSEIF(IMO.EQ.IGO.AND.IDRTO.EQ.4) THEN
       JGO=KGDSO(10)*2
       IF(JMO.EQ.JGO) ISPEC=1
     ENDIF
     IF(ISPEC.EQ.1) THEN
       CALL SPTRUN(IROMB,MAXWV,IDRTI,IMAXI,JMAXI,IDRTO,IMO,JMO, &
                   KM,IPRIME,ISKIPI,JSKIPI,MI,0,0,MO,0,GI,GO)
     ENDIF
!  SPECIAL CASE OF POLAR STEREOGRAPHIC GRID
   ELSEIF(KGDSO(1).EQ.5.AND. &
          KGDSO(2).EQ.KGDSO(3).AND.MOD(KGDSO(2),2).EQ.1.AND. &
          KGDSO(8).EQ.KGDSO(9).AND.KGDSO(11).EQ.64) THEN
     NPS=KGDSO(2)
     RLAT1=KGDSO(4)*1.E-3
     RLON1=KGDSO(5)*1.E-3
     ORIENT=KGDSO(7)*1.E-3
     XMESH=KGDSO(8)
     IPROJ=MOD(KGDSO(10)/128,2)
     IP=(NPS+1)/2
     H=(-1.)**IPROJ
     DE=(1.+SIN(60./DPR))*RERTH
     DR=DE*COS(RLAT1/DPR)/(1+H*SIN(RLAT1/DPR))
     XP=1-H*SIN((RLON1-ORIENT)/DPR)*DR/XMESH
     YP=1+COS((RLON1-ORIENT)/DPR)*DR/XMESH
     IF(NINT(XP).EQ.IP.AND.NINT(YP).EQ.IP) THEN
       IF(IPROJ.EQ.0) THEN
         CALL SPTRUNS(IROMB,MAXWV,IDRTI,IMAXI,JMAXI,KM,NPS, &
                      IPRIME,ISKIPI,JSKIPI,MI,MO,0,0,0, &
                      60.,XMESH,ORIENT,GI,GO,GO2)
       ELSE
         CALL SPTRUNS(IROMB,MAXWV,IDRTI,IMAXI,JMAXI,KM,NPS, &
                      IPRIME,ISKIPI,JSKIPI,MI,MO,0,0,0, &
                      60.,XMESH,ORIENT,GI,GO2,GO)
       ENDIF
       ISPEC=1
     ENDIF
!  SPECIAL CASE OF MERCATOR GRID
   ELSEIF(KGDSO(1).EQ.1) THEN
     NI=KGDSO(2)
     NJ=KGDSO(3)
     RLAT1=KGDSO(4)*1.E-3
     RLON1=KGDSO(5)*1.E-3
     RLON2=KGDSO(8)*1.E-3
     RLATI=KGDSO(9)*1.E-3
     ISCANO=MOD(KGDSO(11)/128,2)
     JSCANO=MOD(KGDSO(11)/64,2)
     NSCANO=MOD(KGDSO(11)/32,2)
     DY=KGDSO(13)
     HI=(-1.)**ISCANO
     HJ=(-1.)**(1-JSCANO)
     DLONO=HI*(MOD(HI*(RLON2-RLON1)-1+3600,360.)+1)/(NI-1)
     DLATO=HJ*DY/(RERTH*COS(RLATI/DPR))*DPR
     IF(NSCANO.EQ.0) THEN
       CALL SPTRUNM(IROMB,MAXWV,IDRTI,IMAXI,JMAXI,KM,NI,NJ, &
                    IPRIME,ISKIPI,JSKIPI,MI,MO,0,0,0, &
                    RLAT1,RLON1,DLATO,DLONO,GI,GO)
       ISPEC=1
     ENDIF
   ENDIF
!  GENERAL SLOW CASE
   IF(ISPEC.EQ.0) THEN
     CALL SPTRUNG(IROMB,MAXWV,IDRTI,IMAXI,JMAXI,KM,NO, &
                  IPRIME,ISKIPI,JSKIPI,MI,MO,0,0,0,RLAT,RLON,GI,GO)
   ENDIF
   DO K=1,KM
     IBO(K)=0
     DO N=1,NO
       LO(N,K)=.TRUE.
     ENDDO
   ENDDO
 ELSE
   DO K=1,KM
     IBO(K)=1
     DO N=1,NO
       LO(N,K)=.FALSE.
       GO(N,K)=0.
     ENDDO
   ENDDO
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE POLATES4

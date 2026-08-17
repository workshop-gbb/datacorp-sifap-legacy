#!/usr/bin/env python3
"""Generate deterministic, synthetic SIFAP Adabas/Natural seed data."""
from __future__ import annotations

import hashlib
import random
import re
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal, ROUND_DOWN
from pathlib import Path

RNG = random.Random(19970512)
OUT = Path(__file__).resolve().parent
TODAY = date(2018, 3, 14)
PERIODS = [201710, 201711, 201712, 201801]

ALLOWED_A = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,'-/()@_+#:&")
CPF_FIELDS = {"NUM-CPF", "CPF-DEPEND", "JB-CPF-REPRESENTATIVE", "NUM-CPF-AFFECTED"}
NIS_FIELDS = {"NUM-NIS"}

FIRST_M = "JOSE CARLOS ANTONIO PAULO LUCAS MARCOS ROBERTO FRANCISCO GABRIEL RAFAEL".split()
FIRST_F = "MARIA ANA JULIA FERNANDA PATRICIA ADRIANA LUCIANA MARCIA CAMILA BEATRIZ".split()
SURNAMES = "SILVA SOUZA OLIVEIRA SANTOS PEREIRA COSTA FERREIRA RODRIGUES ALMEIDA GOMES LIMA RIBEIRO MARTINS CARVALHO".split()
STREETS = ["RUA DAS FLORES", "AVENIDA BRASIL", "RUA SAO JOAO", "TRAVESSA DO MERCADO", "RUA SETE DE SETEMBRO", "AVENIDA CENTRAL"]
DISTRICTS = ["CENTRO", "VILA NOVA", "JARDIM AMERICA", "SANTA LUZIA", "BOA VISTA", "SANTO ANTONIO"]
CITY_BY_UF = {
    "AC": ("RIO BRANCO", 1200401, (69900, 69999), "01"), "AM": ("MANAUS", 1302603, (69000, 69299), "01"),
    "BA": ("SALVADOR", 2927408, (40000, 48999), "02"), "CE": ("FORTALEZA", 2304400, (60000, 63999), "02"),
    "PE": ("RECIFE", 2611606, (50000, 56999), "02"), "GO": ("GOIANIA", 5208707, (72800, 76799), "03"),
    "DF": ("BRASILIA", 5300108, (70000, 72799), "03"), "SP": ("SAO PAULO", 3550308, (1000, 5999), "04"),
    "RJ": ("RIO DE JANEIRO", 3304557, (20000, 23799), "04"), "MG": ("BELO HORIZONTE", 3106200, (30000, 39999), "04"),
    "PR": ("CURITIBA", 4106902, (80000, 87999), "05"), "RS": ("PORTO ALEGRE", 4314902, (90000, 99999), "05"),
    "SC": ("FLORIANOPOLIS", 4205407, (88000, 89999), "05"),
}
PROGRAMS = ["PBF1", "BPC1", "PETI", "AUX1", "GASF", "IDOS"]

@dataclass(frozen=True)
class Field:
    code: str
    name: str
    fmt: str
    length: int
    decimals: int = 0
    occurs: int = 1
    level: int = 1
    opts: str = ""
    remark: str = ""

    @property
    def width(self) -> int:
        if self.fmt == "P":
            return (self.length + 1 + 1) // 2
        return self.length

    @property
    def layout_len(self) -> str:
        return f"{self.length},{self.decimals}" if self.fmt == "P" and self.decimals else str(self.length)

BENEFICIARY = [
    Field('AA','NUM-REGISTRATION','N',11, opts='DE,UQ,FI'), Field('AB','NUM-CPF','A',11, opts='DE,UQ'),
    Field('AC','FULL-NAME','A',60), Field('AD','MOTHER-NAME','A',60), Field('AE','FATHER-NAME','A',60),
    Field('AF','DT-BIRTH','N',8, opts='DE'), Field('AG','SEX','A',1, opts='FI'), Field('AH','MARITAL-STAT','A',1, opts='FI'),
    Field('AI','RG-NUMBER','A',15), Field('AJ','RG-AGENCY','A',10), Field('AK','RG-UF','A',2), Field('AL','RG-DT-ISSUE','N',8),
    Field('AM','NUM-NIS','N',11, opts='DE,UQ'), Field('AN','NUM-BENEFIT','N',13, opts='DE,UQ'),
    Field('BB','STREET-ADDRESS','A',60, level=2), Field('BC','NUMBER','A',10, level=2), Field('BD','ADDRESS-COMPL','A',30, level=2),
    Field('BE','DISTRICT','A',40, level=2), Field('BF','CITY','A',40, level=2), Field('BG','UF','A',2, level=2, opts='DE'),
    Field('BH','CEP','N',8, level=2), Field('BI','COD-IBGE','N',7, level=2), Field('BJ','COD-REGION','A',2, level=2, opts='DE'),
    Field('CA','COD-PROGRAM','A',4, opts='DE'), Field('CB','DT-REGISTRATION','N',8, opts='DE'), Field('CC','DT-START-BENEF','N',8),
    Field('CD','DT-END-BENEF','N',8), Field('CE','STAT-BENEFICIARY','A',1, opts='DE,FI'), Field('CF','REASON-STAT','A',3),
    Field('CG','DT-LAST-STAT','N',8), Field('CH','AMT-FAMILY-INCOME','P',9,2), Field('CI','QTY-FAMILY-MEMBERS','N',2),
    Field('CJ','IND-PERCAP-INCOME','P',7,2), Field('CK','QTY-DEPEND','N',2), Field('CL','IND-DOCS-OK','A',1, opts='FI'),
    Field('DB','CPF-DEPEND','A',11,occurs=10, level=2), Field('DC','NAME-DEPEND','A',60,0,10,2), Field('DD','DT-BIRTH-DEPEND','N',8,0,10,2),
    Field('DE','RELATION','A',2,0,10,2), Field('DF','STAT-DEPEND','A',1,0,10,2), Field('DG','IND-DISABILITY','A',1,0,10,2),
    Field('EA','PHONE-LANDLINE','A',14), Field('EB','PHONE-MOBILE','A',15), Field('EC','EMAIL','A',80), Field('ED','NUM-PHONE','A',15, occurs=5, opts='MU'),
    Field('FA','IND-BIOMETRICS','A',1), Field('FB','DT-COLLECT-BIO','N',8), Field('FC','COD-STATION-BIO','A',6), Field('FD','DIGITAL-HASH','A',64),
    Field('GA','DT-INSERT','N',8, opts='DE'), Field('GB','HR-INSERT','N',6), Field('GC','USR-INSERT','A',8), Field('GD','DT-LAST-UPDATE','N',8),
    Field('GE','HR-LAST-UPDATE','N',6), Field('GF','USR-LAST-UPDATE','A',8), Field('GG','NUM-VERSION','N',5),
    Field('HA','COD-BANK','A',3, opts='DE'), Field('HB','COD-BRANCH','A',6), Field('HC','NUM-ACCOUNT','A',13), Field('HD','TYPE-ACCOUNT','A',1), Field('HE','IND-PORTABILITY','A',1),
    Field('IA','IND-DEATH','A',1), Field('IB','DT-DEATH','N',8), Field('IC','COD-REASON-BLOCK','A',2), Field('ID','IND-JUDICIAL','A',1), Field('IE','NUM-CASE','A',20), Field('IG','COD-PAYER-AGENCY','N',5),
    Field('JA','IND-LEGAL-REPRESENTATIVE','A',1), Field('JB','JB-CPF-REPRESENTATIVE','A',11),
]

PAYMENT = [
    Field('AA','NUM-PAYMENT','N',15), Field('AB','NUM-CPF','A',11), Field('AC','NUM-REGISTRATION','N',11), Field('AD','COD-PROGRAM','A',4), Field('AE','YEAR-MONTH-REF','N',6), Field('AF','NUM-CYCLE','N',6),
    Field('BA','AMT-GROSS','P',9,2), Field('BB','AMT-NET','P',9,2), Field('BC','AMT-DISC-TOTAL','P',7,2), Field('BD','AMT-BONUS','P',9,2),
    Field('CB','TYPE-DISC','A',3,occurs=8), Field('CC','AMT-DISC','P',7,2,occurs=8), Field('CD','PCT-DISC','P',3,2,occurs=8), Field('CE','NUM-CASE','A',20,occurs=8), Field('CF','DT-START-DISC','N',8,occurs=8), Field('CG','DT-END-DISC','N',8,occurs=8),
    Field('DA','STAT-PAYMENT','A',1), Field('DB','DT-GENERATION','N',8), Field('DC','HR-GENERATION','N',6), Field('DD','DT-ISSUE','N',8), Field('DE','DT-CONFIRMATION','N',8), Field('DF','DT-CANCELLATION','N',8), Field('DG','REASON-CANCELLATION','A',3),
    Field('EA','COD-BANK','A',3), Field('EB','COD-BRANCH','A',6), Field('EC','NUM-ACCOUNT','A',13), Field('ED','TYPE-ACCOUNT','A',1), Field('EE','COD-OPERATION','A',3), Field('EF','DT-CREDIT','N',8), Field('EG','TYPE-PAYMENT','A',1),
    Field('FA','NUM-OB-SIAFI','A',12), Field('FB','NUM-NE-SIAFI','A',12), Field('FC','COD-UG-ISSUER','A',6), Field('FD','COD-MANAGEMENT','A',5), Field('FE','STAT-INTEG-SIAFI','A',1), Field('FF','NUM-BATCH','N',8), Field('FG','SEQ-BATCH','N',6),
    Field('GA','DT-RECONCIL','N',8), Field('GB','STAT-RECONCIL','A',1), Field('GC','AMT-RECONCILED','P',9,2), Field('GD','COD-BANK-RETURN','A',2), Field('GE','DESCR-BANK-RETURN','A',40), Field('GF','DT-RETURN','N',8), Field('GG','IND-REVERSAL','A',1), Field('GH','NUM-PAYMENT-ORIGIN','N',15), Field('GI','AMT-CORR','P',9,2), Field('GJ','DT-CORR','N',8), Field('GK','IND-CORR','A',1),
    Field('HA','HASH-REMITTANCE-FILE','A',64), Field('HB','HASH-RETURN-FILE','A',64), Field('HC','COD-OCCURRENCE','A',3,occurs=10,opts='MU'),
    Field('IA','DT-INSERT','N',8), Field('IB','HR-INSERT','N',6), Field('IC','USR-INSERT','A',8), Field('ID','DT-LAST-UPDATE','N',8), Field('IE','HR-LAST-UPDATE','N',6), Field('IF','USR-LAST-UPDATE','A',8),
]

SOCIAL = [
    Field('AA','COD-PROGRAM','A',4), Field('AB','NAME-PROGRAM','A',60), Field('AC','ACRONYM-PROGRAM','A',10), Field('AD','TYPE-PROGRAM','A',1), Field('AE','RESPONSIBLE-AGENCY','A',10), Field('AF','CREATION-LAW','A',20), Field('AG','DT-CREATION','N',8), Field('AH','DT-CLOSURE','N',8), Field('AI','STAT-PROGRAM','A',1),
    Field('BA','AMT-BASE-INDIVIDUAL','P',7,2), Field('BB','AMT-BASE-FAMILY','P',7,2), Field('BC','AMT-CEILING-BENEF','P',9,2), Field('BD','AMT-FLOOR-BENEF','P',7,2), Field('BE','PCT-ANNUAL-ADJUST','P',3,2), Field('BF','DT-LAST-ADJUST','N',8), Field('BG','FACTOR-K','P',5,4), Field('BH','FACTOR-ADJUST','P',3,4),
    Field('CA','MAX-PERCAP-INCOME','P',7,2), Field('CB','AGE-MIN','N',3), Field('CC','AGE-MAX','N',3), Field('CD','IND-REQUIRES-CHILDREN','A',1), Field('CE','QTY-MIN-CHILDREN','N',2), Field('CF','IND-REQUIRES-SCHOOL','A',1), Field('CG','IND-REQUIRES-VACCINE','A',1), Field('CH','IND-REQUIRES-PRENATAL','A',1), Field('CI','IND-REQUIRES-BIOMETRICS','A',1), Field('CJ','COD-ELIGIBILITY','A',5),
    Field('DB','INCOME-START','P',7,2,occurs=5), Field('DC','INCOME-END','P',7,2,occurs=5), Field('DD','FACTOR-MULTIPLIER','P',3,4,occurs=5), Field('DE','AMT-ADDITIONAL','P',7,2,occurs=5), Field('DF','IND-ACCUM','A',1,occurs=5),
    Field('EA','TYPE-DISC-APPLIC','A',3,occurs=8,opts='MU'),
    Field('FB','COD-REGION','A',2,occurs=6), Field('FC','FACTOR-REGIONAL','P',3,4,occurs=6), Field('FD','AMT-REG-COMPLEMENT','P',7,2,occurs=6), Field('FE','IND-ACTIVE-REGION','A',1,occurs=6),
    Field('GA','DT-INSERT','N',8), Field('GB','USR-INSERT','A',8), Field('GC','DT-LAST-UPDATE','N',8), Field('GD','USR-LAST-UPDATE','A',8),
]

AUDIT = [
    Field('AA','NUM-AUDIT','N',15), Field('AB','DT-EVENT','N',8), Field('AC','HR-EVENT','N',6), Field('AD','TS-EVENT','N',14), Field('AE','NUM-TRANSACTION','A',8),
    Field('BA','COD-ACTION','A',2), Field('BB','COD-MODULE','A',8), Field('BC','DESCR-ACTION','A',80), Field('CA','TYPE-ENTITY','A',4), Field('CB','ID-ENTITY','A',15), Field('CC','NUM-CPF-AFFECTED','A',11),
    Field('DB','FIELD-UPDATED-PREV','A',30,occurs=20,opts='MU'), Field('DC','VALUE-PREV','A',80,occurs=20,opts='MU'), Field('DE','FIELD-UPDATED-AFTER','A',30,occurs=20,opts='MU'), Field('DF','VALUE-AFTER','A',80,occurs=20,opts='MU'),
    Field('DG','AMT-PREV','A',60), Field('DH','AMT-NEW','A',60), Field('EA','USR-EVENT','A',8), Field('EB','NAME-USER','A',40), Field('EC','COD-PROFILE','A',3), Field('ED','COD-ASSIGNMENT','A',10), Field('EE','IP-ORIGIN','A',15), Field('EF','ID-SESSION','A',20), Field('EG','COD-TERMINAL','A',8), Field('EH','COD-LU','A',8),
    Field('FA','NUM-CYCLE-BATCH','N',6), Field('FB','NUM-SEQ-BATCH','N',10), Field('FC','NAME-JOB-BATCH','A',16), Field('FD','STAT-BATCH','A',1), Field('FE','DESCR-ERR-BATCH','A',120), Field('GA','ID-CORRELATION','A',36), Field('GB','NUM-SEQ-CORRELATION','N',3),
]

SCHEMAS = {'beneficiary': BENEFICIARY, 'payment': PAYMENT, 'social-program': SOCIAL, 'audit': AUDIT}

def only_digits(s: str) -> str:
    return ''.join(c for c in s if c.isdigit())

def cpf_check(base9: str) -> str:
    nums = [int(c) for c in base9]
    s = sum(n*w for n, w in zip(nums, range(10,1,-1)))
    d1 = 0 if s % 11 < 2 else 11 - (s % 11)
    nums.append(d1)
    s = sum(n*w for n, w in zip(nums, range(11,1,-1)))
    d2 = 0 if s % 11 < 2 else 11 - (s % 11)
    return base9 + str(d1) + str(d2)

def valid_cpf(cpf: str) -> bool:
    return len(cpf) == 11 and cpf.isdigit() and len(set(cpf)) > 1 and cpf_check(cpf[:9]) == cpf

def gen_cpf(prefix: str = '') -> str:
    while True:
        base = prefix + ''.join(str(RNG.randrange(10)) for _ in range(9-len(prefix)))
        cpf = cpf_check(base)
        if valid_cpf(cpf):
            return cpf

def nis_check(base10: str) -> str:
    weights = [3,2,9,8,7,6,5,4,3,2]
    s = sum(int(d)*w for d, w in zip(base10, weights))
    dv = 0 if s % 11 < 2 else 11 - (s % 11)
    return base10 + str(dv)

def valid_nis(nis: str) -> bool:
    return len(nis) == 11 and nis.isdigit() and nis != '00000000000' and nis_check(nis[:10]) == nis

def gen_nis() -> str:
    while True:
        nis = nis_check(''.join(str(RNG.randrange(10)) for _ in range(10)))
        if valid_nis(nis):
            return nis

def d8(dt: date) -> int:
    return int(dt.strftime('%Y%m%d'))

def month_date(period: int, day: int) -> date:
    return date(period // 100, period % 100, min(day, 28))

def money(v) -> Decimal:
    return Decimal(str(v)).quantize(Decimal('0.01'), rounding=ROUND_DOWN)

def pack_p(value, total_digits: int, decimals: int) -> bytes:
    q = Decimal(1).scaleb(-decimals)
    scaled = int(Decimal(str(value)).copy_abs().quantize(q, rounding=ROUND_DOWN) * (10 ** decimals))
    digits = f"{scaled:0{total_digits}d}"
    if len(digits) > total_digits:
        raise ValueError(f"packed overflow {value} P{total_digits},{decimals}")
    nibbles = digits + ('D' if Decimal(str(value)) < 0 else 'C')
    if len(nibbles) % 2:
        nibbles = '0' + nibbles
    return bytes(int(nibbles[i:i+2], 16) for i in range(0, len(nibbles), 2))

def render_value(field: Field, value) -> bytes:
    if field.fmt == 'A':
        text = str(value or '')[:field.length]
        bad = sorted(set(text) - ALLOWED_A)
        if bad:
            raise ValueError(f"invalid A chars {bad} in {field.name}")
        return text.ljust(field.length).encode('ascii')
    if field.fmt == 'N':
        text = str(int(value or 0)).zfill(field.length)
        if len(text) != field.length or not text.isdigit():
            raise ValueError(f"invalid N {field.name}={value}")
        return text.encode('ascii')
    if field.fmt == 'P':
        return pack_p(value or 0, field.length, field.decimals)
    raise ValueError(field.fmt)

def render(schema, rec: dict) -> bytes:
    out = bytearray()
    for field in schema:
        vals = rec.get(field.name, []) if field.occurs > 1 else [rec.get(field.name, '')]
        if field.occurs > 1 and not isinstance(vals, list):
            raise ValueError(f"{field.name} must be list")
        vals = (vals + [''] * field.occurs)[:field.occurs]
        for val in vals:
            out += render_value(field, val)
    return bytes(out)

def record_width(schema) -> int:
    return sum(f.width * f.occurs for f in schema)

def make_name(sex=None):
    sex = sex or RNG.choice(['M','F'])
    first = RNG.choice(FIRST_M if sex == 'M' else FIRST_F)
    return sex, f"{first} {RNG.choice(SURNAMES)} {RNG.choice(SURNAMES)}"

def make_birth(i):
    if i % 17 == 0:
        years = RNG.randrange(8, 17)
    elif i % 19 == 0:
        years = RNG.randrange(66, 83)
    else:
        years = RNG.randrange(18, 65)
    return TODAY - timedelta(days=years * 365 + RNG.randrange(365))

def benefit_amount(b, period):
    base = {'PBF1': 210, 'BPC1': 880, 'PETI': 160, 'AUX1': 320, 'GASF': 120, 'IDOS': 420}[b['COD-PROGRAM']]
    income = Decimal(str(b['AMT-FAMILY-INCOME']))
    factors = [(300, Decimal('1.0000')), (600, Decimal('0.8500')), (1000, Decimal('0.7000')), (1500, Decimal('0.5500')), (999999, Decimal('0.4000'))]
    inc_factor = next(f for lim, f in factors if income <= lim)
    region_factor = {'01':Decimal('1.35'),'02':Decimal('1.40'),'03':Decimal('1.18'),'04':Decimal('1.10'),'05':Decimal('1.05'),'99':Decimal('1.00')}[b['COD-REGION']]
    dep = int(b['QTY-DEPEND'])
    fam = Decimal('1.00') + Decimal(min(dep, 6)) * Decimal('0.04')
    age = period//100 - int(str(b['DT-BIRTH'])[:4])
    age_factor = Decimal('1.15') if age >= 65 else Decimal('1.05') if age < 18 else Decimal('1.00')
    gross = money(Decimal(base) * inc_factor * region_factor * fam * age_factor)
    bonus = money(gross * Decimal('0.15')) if period % 100 == 12 and dep > 0 else Decimal('0.00')
    gross = money(gross + bonus)
    disc = money(gross * Decimal('0.03')) if gross > 500 else Decimal('0.00')
    net = money(gross - disc)
    return gross, disc, net, bonus

def beneficiaries():
    records = []
    income_cases = [0, 120, 299.99, 300, 300.01, 599.99, 600, 600.01, 999.99, 1000, 1000.01, 1499.99, 1500, 1500.01, 2200]
    for i in range(500):
        sex, full = make_name()
        _, mother = make_name('F')
        _, father = make_name('M')
        uf = RNG.choice(list(CITY_BY_UF))
        city, ibge, cepr, region = CITY_BY_UF[uf]
        if i in (7, 77, 177, 277, 377):
            region = '99'
        cpf = gen_cpf('000') if i in (0, 1, 2, 3, 4, 125) else gen_cpf()
        birth = make_birth(i)
        members = RNG.randrange(1, 9)
        income = money(income_cases[i % len(income_cases)] + RNG.randrange(0, 80)) if i >= len(income_cases) else money(income_cases[i])
        dep_count = 10 if i == 10 else (0 if i % 6 == 0 else RNG.randrange(1, min(10, members)+1))
        dependents = {k: [] for k in ['CPF-DEPEND','NAME-DEPEND','DT-BIRTH-DEPEND','RELATION','STAT-DEPEND','IND-DISABILITY']}
        for j in range(10):
            if j < dep_count:
                ds, dn = make_name(RNG.choice(['M','F']))
                dependents['CPF-DEPEND'].append(gen_cpf() if j % 3 else '00000000000')
                dependents['NAME-DEPEND'].append(dn)
                dependents['DT-BIRTH-DEPEND'].append(d8(TODAY - timedelta(days=RNG.randrange(1, 18*365))))
                dependents['RELATION'].append(RNG.choice(['FI','FI','CJ','NT','TU']))
                dependents['STAT-DEPEND'].append(RNG.choice(['A','A','A','I','D']))
                dependents['IND-DISABILITY'].append(RNG.choice(['N','N','N','S']))
            else:
                dependents['CPF-DEPEND'].append('00000000000'); dependents['NAME-DEPEND'].append(''); dependents['DT-BIRTH-DEPEND'].append(0)
                dependents['RELATION'].append('FI'); dependents['STAT-DEPEND'].append('I'); dependents['IND-DISABILITY'].append('N')
        cep = RNG.randrange(cepr[0], cepr[1] + 1)
        rec = {
            'NUM-REGISTRATION': 10000000000 + i, 'NUM-CPF': cpf, 'FULL-NAME': full, 'MOTHER-NAME': mother, 'FATHER-NAME': father,
            'DT-BIRTH': d8(birth), 'SEX': sex, 'MARITAL-STAT': RNG.choice('SCDVU'), 'RG-NUMBER': f"{RNG.randrange(10**7,10**8)}-{RNG.randrange(10)}", 'RG-AGENCY': 'SSP', 'RG-UF': uf, 'RG-DT-ISSUE': d8(birth + timedelta(days=18*365)), 'NUM-NIS': gen_nis(), 'NUM-BENEFIT': 7000000000000 + i,
            'STREET-ADDRESS': RNG.choice(STREETS), 'NUMBER': str(RNG.randrange(1, 2500)), 'ADDRESS-COMPL': RNG.choice(['', 'CASA', 'AP 12', 'FUNDOS', 'BLOCO B']), 'DISTRICT': RNG.choice(DISTRICTS), 'CITY': city, 'UF': uf, 'CEP': cep, 'COD-IBGE': ibge, 'COD-REGION': region,
            'COD-PROGRAM': PROGRAMS[i % len(PROGRAMS)], 'DT-REGISTRATION': d8(TODAY - timedelta(days=RNG.randrange(200, 3000))), 'DT-START-BENEF': d8(TODAY - timedelta(days=RNG.randrange(100, 2500))), 'DT-END-BENEF': 0,
            'STAT-BENEFICIARY': 'A' if i % 20 else RNG.choice(['S','C','I','D']), 'REASON-STAT': '' if i % 20 else 'CAD', 'DT-LAST-STAT': d8(TODAY - timedelta(days=RNG.randrange(0, 400))), 'AMT-FAMILY-INCOME': income, 'QTY-FAMILY-MEMBERS': members, 'IND-PERCAP-INCOME': money(income / Decimal(members)), 'QTY-DEPEND': dep_count, 'IND-DOCS-OK': RNG.choice(['S','S','S','N']),
            'PHONE-LANDLINE': f"({RNG.randrange(11,99)}) {RNG.randrange(2000,5999)}-{RNG.randrange(0,9999):04d}", 'PHONE-MOBILE': f"({RNG.randrange(11,99)}) 9{RNG.randrange(1000,9999)}-{RNG.randrange(0,9999):04d}", 'EMAIL': f"benef{i:03d}@synthetic.example", 'NUM-PHONE': ['']*5,
            'IND-BIOMETRICS': RNG.choice(['S','S','N','P']), 'DT-COLLECT-BIO': d8(TODAY - timedelta(days=RNG.randrange(1, 2000))), 'COD-STATION-BIO': f"ST{RNG.randrange(1,9999):04d}", 'DIGITAL-HASH': hashlib.sha256(f"synthetic-bio-{i}".encode()).hexdigest().upper(),
            'DT-INSERT': 20150301, 'HR-INSERT': 93000+i%10000, 'USR-INSERT': 'SEED', 'DT-LAST-UPDATE': 20180314, 'HR-LAST-UPDATE': 101500, 'USR-LAST-UPDATE': 'SEED', 'NUM-VERSION': 1,
            'COD-BANK': RNG.choice(['001','033','104','237','341']), 'COD-BRANCH': f"{RNG.randrange(1,9999):04d}-{RNG.randrange(10)}", 'NUM-ACCOUNT': f"{RNG.randrange(10000,999999999):012d}-{RNG.randrange(10)}"[:13], 'TYPE-ACCOUNT': RNG.choice(['C','P','S']), 'IND-PORTABILITY': RNG.choice(['S','N']),
            'IND-DEATH': 'N', 'DT-DEATH': 0, 'COD-REASON-BLOCK': '', 'IND-JUDICIAL': RNG.choice(['N','N','S']), 'NUM-CASE': '', 'COD-PAYER-AGENCY': RNG.randrange(1,99999), 'IND-LEGAL-REPRESENTATIVE': RNG.choice(['N','N','S']), 'JB-CPF-REPRESENTATIVE': gen_cpf(),
        }
        rec.update(dependents)
        records.append(rec)
    return records

def social_programs():
    names = [('PBF1','BOLSA FAMILIA SYNTHETIC','PBF','A',210,600,0,0,'S',1), ('BPC1','CONTINUOUS CASH BENEFIT SYNTHETIC','BPC','A',880,1500,65,0,'N',0), ('PETI','CHILD LABOR ERADICATION SYNTHETIC','PETI','A',160,500,0,17,'S',1), ('AUX1','EMERGENCY ASSISTANCE SYNTHETIC','AUX','A',320,1000,18,64,'N',0), ('GASF','GAS FOOD SUPPORT SYNTHETIC','GASF','A',120,300,0,0,'N',0), ('IDOS','ELDERLY SUPPORT SYNTHETIC','IDOS','A',420,900,60,0,'N',0)]
    records=[]
    bands_start=[0,30001,60001,100001,150001]
    bands_end=[30000,60000,100000,150000,999999]
    for idx,(code,name,acr,typ,base,maxinc,agemin,agemax,reqchild,minchild) in enumerate(names):
        records.append({'COD-PROGRAM':code,'NAME-PROGRAM':name,'ACRONYM-PROGRAM':acr,'TYPE-PROGRAM':typ,'RESPONSIBLE-AGENCY':'MDS','CREATION-LAW':f'LAW {9000+idx}/97','DT-CREATION':19970512,'DT-CLOSURE':0,'STAT-PROGRAM':'A','AMT-BASE-INDIVIDUAL':base,'AMT-BASE-FAMILY':base*2,'AMT-CEILING-BENEF':base*6,'AMT-FLOOR-BENEF':base/2,'PCT-ANNUAL-ADJUST':5.75,'DT-LAST-ADJUST':20180101,'FACTOR-K':0.0123,'FACTOR-ADJUST':0.015,'MAX-PERCAP-INCOME':maxinc,'AGE-MIN':agemin,'AGE-MAX':agemax,'IND-REQUIRES-CHILDREN':reqchild,'QTY-MIN-CHILDREN':minchild,'IND-REQUIRES-SCHOOL':'S' if reqchild=='S' else 'N','IND-REQUIRES-VACCINE':'S' if reqchild=='S' else 'N','IND-REQUIRES-PRENATAL':'N','IND-REQUIRES-BIOMETRICS':'S','COD-ELIGIBILITY':f'EL{idx+1:03d}','INCOME-START':[money(x/100) for x in bands_start],'INCOME-END':[money(x/100) for x in bands_end],'FACTOR-MULTIPLIER':[0,0,0,0,0],'AMT-ADDITIONAL':[0,20,35,50,65],'IND-ACCUM':['S','S','N','N','N'],'TYPE-DISC-APPLIC':['IR','JD','CS','PA','EM','TX','OU','EX'],'COD-REGION':['01','02','03','04','05','99'],'FACTOR-REGIONAL':[0,0,0,0,0,0],'AMT-REG-COMPLEMENT':[15,20,12,10,8,0],'IND-ACTIVE-REGION':['S']*6,'DT-INSERT':19970512,'USR-INSERT':'SEED','DT-LAST-UPDATE':20180314,'USR-LAST-UPDATE':'SEED'})
    return records

def payments(benef):
    records=[]; seq=1
    active = benef
    for period in PERIODS:
        for idx,b in enumerate(active):
            gross,disc,net,bonus = benefit_amount(b,period)
            if idx % 113 == 0:
                net = money(net + Decimal('0.03'))  # report imbalance fixture (M-05)
            stat = ['C','C','P','G','D','E','R'][idx % 7]
            reversal = 'S' if idx % 97 == 0 else 'N'
            recon = 'D' if idx % 89 == 0 else ('C' if stat in 'CP' else 'P')
            rec = {'NUM-PAYMENT':900000000000000+seq,'NUM-CPF':b['NUM-CPF'],'NUM-REGISTRATION':b['NUM-REGISTRATION'],'COD-PROGRAM':b['COD-PROGRAM'],'YEAR-MONTH-REF':period,'NUM-CYCLE':period,'AMT-GROSS':gross,'AMT-NET':net,'AMT-DISC-TOTAL':disc,'AMT-BONUS':bonus,
                   'TYPE-DISC':['IR' if disc else '']+['']*7,'AMT-DISC':[disc]+[0]*7,'PCT-DISC':[3.00 if disc else 0]+[0]*7,'NUM-CASE':['']*8,'DT-START-DISC':[d8(month_date(period,1)) if disc else 0]+[0]*7,'DT-END-DISC':[0]*8,
                   'STAT-PAYMENT':stat,'DT-GENERATION':d8(month_date(period,3)),'HR-GENERATION':223000,'DT-ISSUE':d8(month_date(period,5)),'DT-CONFIRMATION':d8(month_date(period,8)) if stat in 'CPD' else 0,'DT-CANCELLATION':d8(month_date(period,9)) if stat in 'XE' else 0,'REASON-CANCELLATION':'RET' if stat in 'DE' else '',
                   'COD-BANK':b['COD-BANK'],'COD-BRANCH':b['COD-BRANCH'],'NUM-ACCOUNT':b['NUM-ACCOUNT'],'TYPE-ACCOUNT':b['TYPE-ACCOUNT'] if b['TYPE-ACCOUNT'] in ['C','P'] else 'P','COD-OPERATION':'013','DT-CREDIT':d8(month_date(period,10)) if stat in 'CP' else 0,'TYPE-PAYMENT':'N' if period%100 != 12 else 'A',
                   'NUM-OB-SIAFI':f"OB{seq:010d}",'NUM-NE-SIAFI':f"NE{seq:010d}",'COD-UG-ISSUER':'550008','COD-MANAGEMENT':'00001','STAT-INTEG-SIAFI':'E' if idx%101==0 else 'I','NUM-BATCH':period*100+1,'SEQ-BATCH':idx+1,
                   'DT-RECONCIL':d8(month_date(period,12)) if recon != 'P' else 0,'STAT-RECONCIL':recon,'AMT-RECONCILED':money(net + (Decimal('1.25') if recon=='D' else 0)),'COD-BANK-RETURN':'01' if stat=='D' else '00','DESCR-BANK-RETURN':'DIVERGENT AMOUNT' if recon=='D' else 'CREDIT CONFIRMED','DT-RETURN':d8(month_date(period,12)) if stat in 'CPD' else 0,'IND-REVERSAL':reversal,'NUM-PAYMENT-ORIGIN':900000000000000+seq-1 if reversal and seq>1 else 0,'AMT-CORR':Decimal('1.25') if recon=='D' else 0,'DT-CORR':d8(month_date(period,13)) if recon=='D' else 0,'IND-CORR':'S' if recon=='D' else 'N',
                   'HASH-REMITTANCE-FILE':hashlib.sha256(f"rem-{period}-{idx}".encode()).hexdigest().upper(),'HASH-RETURN-FILE':hashlib.sha256(f"ret-{period}-{idx}".encode()).hexdigest().upper(),'COD-OCCURRENCE':['00','01' if stat=='D' else '','RJ' if reversal=='S' else '']+['']*7,
                   'DT-INSERT':d8(month_date(period,3)),'HR-INSERT':223000,'USR-INSERT':'BATCH','DT-LAST-UPDATE':d8(month_date(period,13)),'HR-LAST-UPDATE':101112,'USR-LAST-UPDATE':'BATCH'}
            records.append(rec); seq += 1
    return records

def audits(benef, pay):
    actions = [('IN','CADBENEF','BENF'),('AL','CADBENEF','BENF'),('BT','BATCHPGT','PGTO'),('BT','BATCHCON','PGTO'),('ER','BATCHCON','PGTO'),('CO','CONSBENF','BENF')]
    records=[]
    for i in range(200):
        act, mod, ent = actions[i % len(actions)]
        b = benef[i % len(benef)]; p = pay[i % len(pay)]
        dt = d8(TODAY - timedelta(days=i % 120)); hr = 80000 + (i * 37) % 9000
        descr = {'IN':'SYNTHETIC BENEFICIARY INSERT','AL':'SYNTHETIC BENEFICIARY CHANGE','BT':'SYNTHETIC BATCH EXECUTION','ER':'SYNTHETIC RECONCILIATION ERROR','CO':'SYNTHETIC CONSULTATION'}[act]
        fields_prev = ['AMT-NET','STAT-RECONCIL','IND-REVERSAL'] + ['']*17
        fields_after = ['AMT-NET','STAT-RECONCIL','IND-REVERSAL'] + ['']*17
        values_prev = [str(p['AMT-NET']), 'P', 'N'] + ['']*17
        values_after = [str(p['AMT-RECONCILED']), p['STAT-RECONCIL'], p['IND-REVERSAL']] + ['']*17
        records.append({'NUM-AUDIT':800000000000000+i,'DT-EVENT':dt,'HR-EVENT':hr,'TS-EVENT':int(f"{dt}{hr:06d}"),'NUM-TRANSACTION':f"TR{i:06d}",'COD-ACTION':act,'COD-MODULE':mod,'DESCR-ACTION':descr,'TYPE-ENTITY':ent,'ID-ENTITY':str(p['NUM-PAYMENT'] if ent=='PGTO' else b['NUM-REGISTRATION']),'NUM-CPF-AFFECTED':b['NUM-CPF'],'FIELD-UPDATED-PREV':fields_prev,'VALUE-PREV':values_prev,'FIELD-UPDATED-AFTER':fields_after,'VALUE-AFTER':values_after,'AMT-PREV':str(p['AMT-NET']),'AMT-NEW':str(p['AMT-RECONCILED']),'USR-EVENT':RNG.choice(['OPER01','AUDIT01','BATCH','SUPERV']),'NAME-USER':'SYNTHETIC OPERATOR','COD-PROFILE':RNG.choice(['ADM','OPR','CON','AUD','SUP']),'COD-ASSIGNMENT':'MDAS-SYN','IP-ORIGIN':f"10.10.{i%20}.{10+i%200}",'ID-SESSION':f"SYN{i:017d}",'COD-TERMINAL':f"T{i%9999:04d}",'COD-LU':f"LU{i%9999:04d}",'NUM-CYCLE-BATCH':p['YEAR-MONTH-REF'],'NUM-SEQ-BATCH':i+1,'NAME-JOB-BATCH':'SIFAPSEED','STAT-BATCH':'E' if act=='ER' else 'S','DESCR-ERR-BATCH':'DIVERGENT BANK RETURN' if act=='ER' else '','ID-CORRELATION':f"00000000-0000-0000-0000-{i:012d}",'NUM-SEQ-CORRELATION':(i%999)+1})
    return records

def write_records(name, schema, records):
    width = record_width(schema)
    with (OUT / f"{name}.dat").open('wb') as fh:
        for rec in records:
            row = render(schema, rec)
            if len(row) != width:
                raise AssertionError(f"{name} row len {len(row)} != {width}")
            fh.write(row + b'\n')

def write_layout(name, schema):
    lines = [f"# ADACMP-style layout for {name}.dat", "# Derived from SIFAP DDM/FDT; groups are flattened, MU/PE fully expanded.", "# LEVEL CODE NAME FORMAT LENGTH OCCURS OPTIONS BYTE-WIDTH"]
    for f in schema:
        lines.append(f"{f.level:02d} {f.code:<2} {f.name:<28} {f.fmt:<1} {f.layout_len:<5} {f.occurs:<3} {f.opts or '-':<10} {f.width * f.occurs}")
    lines.append(f"# RECORD-BYTES {record_width(schema)}")
    (OUT / f"layout-{name}.txt").write_text('\n'.join(lines) + '\n', encoding='utf-8')

def read_dat_records(path: Path):
    return path.read_bytes().splitlines()

def verify_file(name, schema, expected):
    rows = read_dat_records(OUT / f"{name}.dat")
    width = record_width(schema)
    assert len(rows) == expected, (name, len(rows), expected)
    for row in rows:
        assert len(row) == width, (name, len(row), width)
        pos = 0
        for f in schema:
            for _ in range(f.occurs):
                chunk = row[pos:pos+f.width]; pos += f.width
                if f.fmt == 'A':
                    text = chunk.decode('ascii')
                    assert set(text.rstrip()) <= ALLOWED_A, (name, f.name, text)
                    stripped = text.strip()
                    if f.name in CPF_FIELDS and stripped and stripped != '00000000000':
                        assert valid_cpf(stripped), (name, f.name, stripped)
                elif f.fmt == 'N':
                    text = chunk.decode('ascii')
                    assert text.isdigit(), (name, f.name, text)
                    if f.name in NIS_FIELDS and text != '00000000000':
                        assert valid_nis(text), (name, f.name, text)
                elif f.fmt == 'P':
                    assert len(chunk) == f.width
    return len(rows), width

def write_readme(counts):
    text = f"""# SIFAP Legacy Lab Synthetic Seed Data

This directory contains deterministic fixed-width seed files for the Adabas/Natural SIFAP lab.

**Synthetic data statement:** this is 100% synthetic Brazilian test data. It contains no real personal data, no real CPF/NIS assignments, and no production records.

## Files and volumes

| File | Records | Bytes/record (without newline) | Source layout |
|---|---:|---:|---|
| `beneficiary.dat` | {counts['beneficiary'][0]} | {counts['beneficiary'][1]} | `layout-beneficiary.txt`, file 150 BENEFICIARY |
| `payment.dat` | {counts['payment'][0]} | {counts['payment'][1]} | `layout-payment.txt`, file 152 PAYMENT |
| `social-program.dat` | {counts['social-program'][0]} | {counts['social-program'][1]} | `layout-social-program.txt`, file 151 SOCIAL-PROGRAM |
| `audit.dat` | {counts['audit'][0]} | {counts['audit'][1]} | `layout-audit.txt`, file 153 AUDIT |

## Regeneration

Run from this directory or from the repository root:

```bash
python3 infra/adabas-natural-lab/provisioning/seed/generate_seed.py
```

The generator uses only the Python 3 standard library and a fixed RNG seed, so outputs are reproducible.

## Layout notes

Records are one physical record per line. Alphanumeric fields are ASCII, trailing-space padded. Numeric unpacked fields are zero-left-padded digits. Packed decimal fields are binary packed BCD with an implied decimal scale as declared in the DDM/FDT; the newline is not part of the record width.

Periodic groups and MU fields are emitted at their maximum occurrence counts so sibling ADACMP/ADALOD scripts can load deterministic full-width records.

## Teaching fixtures

- Valid CPF and NIS check digits are generated with the mod-11 algorithms used by `SUBVALCP.NSN` and `SUBVALNI.NSN`.
- Several beneficiaries have valid CPF values starting with `000` for the government-test exception path.
- Family incomes cross the 300/600/1000/1500 calculation bands.
- Region `99` beneficiaries exercise the international/diplomatic eligibility bypass.
- Dependents include zero, several, inactive/disconnected statuses, and one 10-occurrence maximum record.
- Payments include reversals, divergent reconciliation, bank returns, and intentionally imbalanced gross/discount/net rows for report labs.
"""
    (OUT / 'README.md').write_text(text, encoding='utf-8')

def main():
    benef = beneficiaries()
    soc = social_programs()
    pay = payments(benef)
    aud = audits(benef, pay)
    datasets = {'beneficiary': benef, 'payment': pay, 'social-program': soc, 'audit': aud}
    expected = {'beneficiary': 500, 'payment': 2000, 'social-program': 6, 'audit': 200}
    for name, schema in SCHEMAS.items():
        write_layout(name, schema)
        write_records(name, schema, datasets[name])
    counts = {name: verify_file(name, SCHEMAS[name], expected[name]) for name in SCHEMAS}
    write_readme(counts)
    for name in ['beneficiary','payment','social-program','audit']:
        print(f"OK {name}.dat records={counts[name][0]} bytes_per_record={counts[name][1]}")
    print("OK CPF/NIS mod-11 checks, field character checks, and record counts passed")

if __name__ == '__main__':
    main()

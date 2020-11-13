module Snoopy
  CBTE_TYPE = { '01' => 'Factura A',
                '02' => 'Nota de Débito A',
                '03' => 'Nota de Crédito A',
                '04' => 'Recibos A',
                '05' => 'Notas de Venta al contado A',
                '06' => 'Factura B',
                '07' => 'Nota de Debito B',
                '08' => 'Nota de Credito B',
                '09' => 'Recibos B',
                '10' => 'Notas de Venta al contado B',
                '11' => 'Factura C',
                '13' => 'Nota de Crédito C',
                '34' => 'Cbtes. A del Anexo I, Apartado A,inc.f),R.G.Nro. 1415',
                '35' => 'Cbtes. B del Anexo I,Apartado A,inc. f),R.G. Nro. 1415',
                '39' => 'Otros comprobantes A que cumplan con R.G.Nro. 1415',
                '40' => 'Otros comprobantes B que cumplan con R.G.Nro. 1415',
                '60' => 'Cta de Vta y Liquido prod. A',
                '61' => 'Cta de Vta y Liquido prod. B',
                '63' => 'Liquidacion A',
                '64' => 'Liquidacion B' }

  # [:TLSv1_2, :TLSv1_1, :TLSv1, :SSLv3, :SSLv23, :SSLv2]
  SNOOPY_SSL_VERSION = (ENV['SNOOPY_SSL_VERSION'] || 'TLSv1').to_sym

  RESPONSABLE_INSCRIPTO   = :responsable_inscripto
  RESPONSABLE_MONOTRIBUTO = :responsable_monotributo

  IVA_COND = [ RESPONSABLE_MONOTRIBUTO, RESPONSABLE_INSCRIPTO ]

  CONCEPTS = { 'Productos'             => '01',
               'Servicios'             => '02',
               'Productos y Servicios' => '03' }

  DOCUMENTS = { 'CUIT'                   => '80',
                'CUIL'                   => '86',
                'CDI'                    => '87',
                'LE'                     => '89',
                'LC'                     => '90',
                'CI Extranjera'          => '91',
                'en tramite'             => '92',
                'Acta Nacimiento'        => '93',
                'CI Bs. As. RNP'         => '95',
                'DNI'                    => '96',
                'Pasaporte'              => '94',
                'Doc. (Otro)'            => '99',
                'CI Policía Federal'     => '00',
                'CI Buenos Aires'        => '01',
                'CI Catamarca'           => '02',
                'CI Córdoba'             => '03',
                'CI Corrientes'          => '04',
                'CI Entre Ríos'          => '05',
                'CI Jujuy'               => '06',
                'CI Mendoza'             => '07',
                'CI La Rioja'            => '08',
                'CI Salta'               => '09',
                'CI San Juan'            => '10',
                'CI San Luis'            => '11',
                'CI Santa Fe'            => '12',
                'CI Santiago del Estero' => '13',
                'CI Tucumán'             => '14',
                'CI Chaco'               => '16',
                'CI Chubut'              => '17',
                'CI Formosa'             => '18',
                'CI Misiones'            => '19',
                'CI Neuquén'             => '20',
                'CI La Pampa'            => '21',
                'CI Río Negro'           => '22',
                'CI Santa Cruz'          => '23',
                'CI Tierra del Fuego'    => '24' }

  CURRENCY = { :peso  => { :code => 'PES', :nombre => 'Pesos Argentinos' },
               :dolar => { :code => 'DOL', :nombre => 'Dolar Estadounidense' },
               :real  => { :code => '012', :nombre => 'Real' },
               :euro  => { :code => '060', :nombre => 'Euro' },
               :oro   => { :code => '049', :nombre => 'Gramos de Oro Fino' } }

  ALIC_IVA = { 0     => '3',
               0.0   => '3',
               0.025 => '9',
               0.05  => '8',
               0.105 => '4',
               0.21  => '5',
               0.27  => '6' }

  BILL_TYPE = { :factura_a      => '01',
                :factura_b      => '06',
                :factura_c      => '11',
                :nota_credito_a => '03',
                :nota_credito_b => '08',
                :nota_credito_c => '13' }
end

import 'package:vera/features/inteligencia/data/modelos.dart';

/// Una categoría que el usuario puede elegir en la corrección.
class CategoriaVisible {
  const CategoriaVisible(this.codigo, this.nombre);

  final String codigo;
  final String nombre;
}

/// Las diez categorías de gasto del catálogo cerrado.
const categoriasDeGasto = <CategoriaVisible>[
  CategoriaVisible('alimentos_mercado', 'Alimentos y mercado'),
  CategoriaVisible('restaurantes_domicilios', 'Restaurantes y domicilios'),
  CategoriaVisible('transporte', 'Transporte'),
  CategoriaVisible('vivienda_servicios', 'Vivienda y servicios'),
  CategoriaVisible('salud', 'Salud'),
  CategoriaVisible('educacion', 'Educación'),
  CategoriaVisible('entretenimiento', 'Entretenimiento'),
  CategoriaVisible('compras', 'Compras'),
  CategoriaVisible(
    'comisiones_costos_financieros',
    'Comisiones y costos financieros',
  ),
  CategoriaVisible('otros_gastos', 'Otros gastos'),
];

/// Las cuatro categorías de ingreso del catálogo cerrado.
const categoriasDeIngreso = <CategoriaVisible>[
  CategoriaVisible('salario', 'Salario'),
  CategoriaVisible('transferencia_recibida', 'Transferencia recibida'),
  CategoriaVisible('reembolso', 'Reembolso'),
  CategoriaVisible('otros_ingresos', 'Otros ingresos'),
];

/// Las categorías que se ofrecen según la dirección. `sin_categoria` no se
/// ofrece nunca: no se puede volver a dejar un movimiento sin clasificar.
List<CategoriaVisible> categoriasPara(DireccionMovimiento direccion) =>
    switch (direccion) {
      DireccionMovimiento.entrada => categoriasDeIngreso,
      DireccionMovimiento.salida => categoriasDeGasto,
    };

export function nextJsonRpcId(state: { n: number }): number {
  state.n += 1;
  return state.n;
}

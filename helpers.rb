# frozen_string_literal: true

def sierra_round(n, dirn)
  if (dirn < 0)
    return ((n - n.floor <= 0.501) ? n.floor : n.ceil)
  end

  ((n - n.floor < 0.499) ? n.floor : n.ceil)
end

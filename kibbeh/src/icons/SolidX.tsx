import * as React from "react";

export default function SvgSolidX(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      width={16}
      height={16}
      viewBox="0 0 16 16"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path
        d="M9.52217 6.77491L14.0867 1.53906H12.7153L8.82587 5.89387L5.71947 1.53906H1.61328L6.40387 8.38429L1.61328 13.9191H2.98466L7.09987 9.26533L10.3881 13.9191H14.4943L9.52187 6.77491H9.52217ZM7.70797 8.44629L7.22227 7.75346L3.37647 2.55569H5.05997L8.14007 6.67029L8.62577 7.36312L12.716 12.9305H11.0325L7.70797 8.44659V8.44629Z"
        fill="white"
      />
    </svg>
  );
}
